// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../interface/IStayking.sol";
import "../interface/IVault.sol";
import "../interface/ISwapHelper.sol";
import "../interface/IUnbondedEvmos.sol";
import "../lib/utils/SafeToken.sol";
import "../lib/OwnableUpgradeable.sol";
import "../lib/ReentrancyGuardUpgradeable.sol";

contract Stayking is IStayking, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    address private constant BASE_TOKEN = address(0);

    event Stake(address indexed delegator, address indexed user, uint256 amount, uint256 share);
    event Unstake(address indexed delegator, address indexed user, uint256 amount, uint256 share);
    event AddPosition(address indexed user, address indexed vault, uint256 equity, uint256 debtInBase, uint256 debt, uint256 share);
    event RemovePosition(address indexed user, address indexed vault, uint256 equity, uint256 debtInBase, uint256 debt, uint256 share);
    event PositionChanged(address indexed user, address indexed vault, uint256 amount, uint256 share, uint256 debt);
    event Kill(address indexed killer, address indexed user, address vault, uint256 equity, uint256 debtInBase, uint256 debt, uint256 share);
    event Accrue(address indexed delegator, uint256 amount);

    // Operation Events
    event AddVault(address token, address vault);
    event UpdateVault(address token, address vault);
    event UpdateConfigs(uint256 minDebtInBase, uint256 killFactorBps);
    event ChangeDelegator(address delegator);

    address public delegator;
    mapping(address => bool) public whitelistedKiller;

    mapping(address => address) public override tokenToVault;

    /// @dev kor) 유저가 예치한 금액 + auto-compound된 금액
    uint256 public totalAmount; 
    /// @dev kor) auto-compound되어도 totalShare는 변하지 않음.
    ///  유저는 예치하는 시점에 (예치 금액/totalAmount) * totalShare에 해당하는 share를 받음.
    uint256 public totalShare;  

    /// @dev min debtAmount in EVMOS (base token)
    uint256 public override minDebtInBase;
    uint256 public override killFactorBps;
    
    IUnbondedEvmos public uEVMOS;

    struct Position {
        address user;
        /// @dev totalShare * (equity + debtInBase) / totalAmount
        uint256 share;
    }

    /// @dev userAddress => vaultAddress => positionId (array Index of position)
    mapping(address => mapping(address => uint256)) public positionIdOf;
    /// @dev vaultAddress => Position[]
    mapping(address => Position[]) public positions;
    mapping(address => uint256) public positionsLengthOf;

    // debt To Vault
    mapping (address => uint256) public totalDebtOf;

    /*************
     * Modifiers *
    **************/

    modifier onlyDelegator(){
        require(
            // whitelistedDelegator[msg.sender],
            msg.sender == delegator,
            "Stayking: Not whitelisted delegator."
        );
        _;
    }

    modifier onlyKiller(){
        require(
            whitelistedKiller[msg.sender],
            "Stayking: Not whitelisted Killer."
        );
        _;
    }

    function __Stayking_init(
        address delegator_,
        address uEVMOS_
    ) external initializer {
        __Ownable_init();
        __ReentrancyGuard_init();

        // @TODO policy
        updateConfigs(
            10e18,  // minDebtInBase (10EVMOS)
            8000    // killFactorBps
        );

        uEVMOS = IUnbondedEvmos(uEVMOS_);
        changeDelegator(delegator_);
    }

    /**********************
     * Operate Functions *
    ***********************/

    function changeDelegator (
        address _delegator
    ) public override onlyOwner {
        delegator = _delegator;
        emit ChangeDelegator(_delegator);
    }

    function updateVault(
        address token, 
        address vault
    ) public override onlyOwner {
        bool isNewVault = (tokenToVault[token] == address(0));

        if(isNewVault)
            emit AddVault(token, vault);
        else {
            require(
                IVault(tokenToVault[token]).totalDebtAmount() == 0,
                "updateVault: Debt remains on the existing vault."
            );
            emit UpdateVault(token, vault);
        }

        tokenToVault[token] = vault;
        // push null position
        positions[vault].push(
            Position({
                user: address(0),
                share: 0
            })
        );
    }

    function updateConfigs(
        uint256 _minDebtInBase,
        uint256 _killFactorBps
    ) public onlyOwner {
        minDebtInBase = _minDebtInBase;
        killFactorBps = _killFactorBps;
        emit UpdateConfigs(_minDebtInBase, _killFactorBps);
    }

    /***********************
     * Private Functions *
    ************************/
    function _stake(
        Position storage p,
        uint256 amount
    ) private returns (uint256 share) {
        share = amountToShare(amount);
        p.share += share;
        totalAmount += amount;
        totalShare += share;
        // send EVMOS to delegator
        SafeToken.safeTransferEVMOS(delegator, amount);
        
        emit Stake(delegator, p.user, amount, share);
    }


    function _unstake(
        Position storage p,
        address vault,
        uint256 share
    ) private returns(uint256 amount) {
        amount = shareToAmount(share);
        p.share -= share;
        totalAmount -= amount;
        totalShare -= share;

        uEVMOS.mintLockedToken(
            p.user, 
            vault,
            amount
        );

        emit Unstake(delegator, p.user, amount, share);
    }

    function _isHealthy(
        address vault,
        uint256 share,
        uint256 debt
    ) private view returns(bool healthy, uint256 debtInBase) {
        debtInBase = IVault(vault).getBaseIn(debt);
        healthy = debtInBase * 1e4 < shareToAmount(share) * killFactorBps;
    }

    /******************
     * Util Functions *
    *******************/
    /// @notice 
    /// 유저는 예치하는 시점에 (예치 금액 / totalAmount) * totalShare에 해당하는 share를 받음.
    function amountToShare(uint256 amount) public view returns(uint256) {
        return (totalAmount == 0) ? amount : (totalShare * amount) / totalAmount;
    }

    function shareToAmount(uint256 share) public view returns(uint256) {
        return (totalShare == 0) ? share : (totalAmount * share) / totalShare;
    }

    /******************************
     * Interface implementations *
    *******************************/
    function debtAmountOf(
        address user, 
        address vault
    ) public view override returns(uint256) {
        return IVault(vault).debtAmountOf(user);
    }

    /// @param debtToken    debtToken Address (not vault address)
    /// @param equity       equityAmount in EVMOS
    /// @param debtInBase   debtAmount in EVMOS
    function addPosition(
        address debtToken,
        uint256 equity,
        uint256 debtInBase
    ) public payable override {
        address vault = tokenToVault[debtToken];
        require(positionIdOf[msg.sender][vault] > 0, "addPosition: already have position");
        require(equity == msg.value, "addPosition: msg.value != equity");
        
        uint256 amount = equity + debtInBase;
        require(
            debtInBase * 1e4 < amount * killFactorBps,
            "addPosition: bad debt, cannot open position"
        );

        // borrow token from vault
        uint256 debt = IVault(vault).loan(msg.sender, debtInBase);

        positions[vault].push(
            Position({
                user: msg.sender,
                share: 0
            })
        );

        uint256 positionId = positionsLengthOf[vault];
        positionsLengthOf[vault] += 1;
        positionIdOf[msg.sender][vault] = positionId;

        uint256 share = _stake(positions[vault][positionId], amount);

        emit AddPosition(msg.sender, vault, equity, debtInBase, debt, share);
    }


    /// @dev remove all position of debtToken vault.
    /// @param debtToken    debtToken Address (not vault address)
    /// @notice kor) 부채비율이 100%가 넘어가면 포지션을 직접 종료할 수 없다. -> 강제 청산만 가능.
    function removePosition(
        address debtToken
    ) public override {
        address vault = tokenToVault[debtToken];
        Position storage p = positions[vault][positionIdOf[msg.sender][vault]];
        require(p.share > 0, "removePosition: No position for this token");

        uint256 debtAmount = debtAmountOf(msg.sender, vault);
        // 1. check if user can repay debt
        /// @dev amount in EVMOS that user have to repay
        uint256 currentDebtInBase = IVault(vault).getBaseIn(debtAmount);

        uint256 unstakedAmount = _unstake(p, vault, p.share);
        require(
            unstakedAmount >= currentDebtInBase,
            "removePosition: Bad debt"
        );

        emit RemovePosition(
            msg.sender, 
            vault, 
            unstakedAmount - currentDebtInBase, // equity
            currentDebtInBase,                  // debt
            debtAmount, 
            p.share
        );

        positionIdOf[msg.sender][vault] = 0; // kor) positionId 초기화
    }

    /// @dev Borrow more debt (increase debt ratio)
    /// @param debtToken    debtToken Address (not vault address)
    /// @param extraDebtInBase  amount of additional debt in EVMOS
    function addDebt(
        address debtToken,
        uint256 extraDebtInBase
    ) public override {
        address vault = tokenToVault[debtToken];        
        Position storage p = positions[vault][positionIdOf[msg.sender][vault]];

        require(p.share > 0, "addDebt: no position in for this token.");
        require(extraDebtInBase > 0, "addDebt: extraDebtInBase <= 0");

        // borrow token from vault
        IVault(vault).loan(msg.sender, extraDebtInBase);
        _stake(p, extraDebtInBase);
        
        uint256 debtAmount = debtAmountOf(msg.sender, vault);
        (bool healthy, ) = _isHealthy(vault, p.share, debtAmount);
        require(healthy, "addDebt: bad debt, cannot add more debt anymore.");

        emit PositionChanged(
            msg.sender, 
            vault, 
            shareToAmount(p.share),
            p.share,
            debtAmount
        );

    }

    /// @dev Repay debt (decrease debt ratio, total staked amount(or share) does not change)
    /// @notice user should repay debt using debtToken
    /// @notice user approve should be preceded
    /// @param debtToken    debtToken Address (not vault address)
    /// @param repaidDebt  amount of repaid debt in debtToken
    function repayDebt(
        address debtToken,
        uint256 repaidDebt
    ) public override {
        address vault = tokenToVault[debtToken];        
        Position storage p = positions[vault][positionIdOf[msg.sender][vault]];
        uint256 debtAmount = debtAmountOf(msg.sender, vault); 

        SafeToken.safeTransferFrom(
            debtToken,
            msg.sender,
            address(this),
            repaidDebt
        );
        SafeToken.safeApprove(debtToken, vault, repaidDebt);
        IVault(vault).repayInToken(msg.sender, repaidDebt);

        emit PositionChanged(
            msg.sender, 
            vault, 
            shareToAmount(p.share),
            p.share,
            debtAmount - repaidDebt
        );    
    }

    /// @dev Repay debt with EVMOS (decrease debt ratio, total staked amount(or share) does not change)
    /// @param debtToken    debtToken Address (not vault address)
    /// @param minRepaid    minimum value to be repaid
    /// @notice repaidDebtInBase = msg.value
    function repayDebtInBase(
        address debtToken,
        uint256 minRepaid
    ) public payable override {
        address vault = tokenToVault[debtToken];        
        Position storage p = positions[vault][positionIdOf[msg.sender][vault]];
        uint256 debtAmount = debtAmountOf(msg.sender, vault); 

        uint256 repaidDebt = IVault(vault).repayInBase{value: msg.value}(msg.sender, minRepaid);
        emit PositionChanged(
            msg.sender, 
            vault, 
            shareToAmount(p.share),
            p.share,
            debtAmount - repaidDebt
        );    
    }


    /// @dev add additional equity (decrease debt ratio)
    /// @param debtToken    debtToken Address (not vault address)
    /// @param extraEquity  amount of additional equity
    function addEquity(
        address debtToken,
        uint256 extraEquity
    ) payable public override {
        address vault = tokenToVault[debtToken];        
        Position storage p = positions[vault][positionIdOf[msg.sender][vault]];

        _stake(p, extraEquity);
        emit PositionChanged(
            msg.sender, 
            vault, 
            shareToAmount(p.share),
            p.share,
            debtAmountOf(msg.sender, vault)
        ); 
    }


    function isKillable(
        address debtToken,
        uint256 positionId
    ) public override view returns(bool healthy) {
        address vault = tokenToVault[debtToken];
        Position memory p = positions[vault][positionId];
        
        if(p.share == 0)    /// @dev removed position
            return false;
        (healthy, ) = _isHealthy(vault, p.share, debtAmountOf(p.user, vault));
    }
    
    function kill(
        address debtToken,
        uint256 positionId
    ) public override onlyKiller {
        address vault = tokenToVault[debtToken];
        Position storage p = positions[vault][positionId];
        require(p.share > 0, "kill: removed position");

        uint256 debt = debtAmountOf(p.user, vault);
        (bool healthy, uint256 debtInBase) = _isHealthy(vault, p.share, debt);
        require(healthy, "kill: still safe position.");

        uint256 unStakedAmount = _unstake(p, vault, p.share);

        emit Kill(
            msg.sender, 
            p.user, 
            vault, 
            unStakedAmount - debtInBase,
            debtInBase, 
            debt, 
            p.share
        );

    }

    /***********************
     * Only for Delegator *
     ***********************/
    function accrue(
        uint256 currentTotalStaked
    ) payable public onlyDelegator override {
        //// WARN!!
        //// kor) delegator가 잘못 param을 넘겨주면 전체 유저의 수익이 좌지우지될 수 있음..!!
        require(currentTotalStaked >= totalAmount, "accrue: currentTotalStaked < totalAmount");
        uint256 compounded = currentTotalStaked - totalAmount;
        totalAmount = currentTotalStaked;
        emit Accrue(msg.sender, compounded);
    }

    /// @dev Fallback function to accept EVMOS.
    receive() external payable {}
}