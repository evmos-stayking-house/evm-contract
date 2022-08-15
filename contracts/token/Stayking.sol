// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../interface/IStayking.sol";
import "../interface/IVault.sol";
import "../interface/ISwapHelper.sol";
import "../lib/utils/SafeToken.sol";
import "../lib/OwnableUpgradeable.sol";
import "../lib/ReentrancyGuardUpgradeable.sol";

contract Stayking is IStayking, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    address public constant BASE_TOKEN = address(0);

    event Stake(address user, uint256 amount, uint256 share);
    event Unstake(address user, uint256 amount, uint256 share);
    event AddPosition(address user, address vault, uint256 equity, uint256 debtInBase, uint256 debt, uint256 share);
    event RemovePosition(address user, address vault, uint256 equity, uint256 debtInBase, uint256 debt, uint256 share);
    event PositionChanged(address user, address vault, uint256 amount, uint256 share, uint256 debt);
    // @TODO
    event Kill(address user); 
    event Accrue(address delegator, uint256 amount);

    // Operation Events
    event AddVault(address token, address vault);
    event ChangeVault(address token, address vault);
    event ChangeConfigs(uint256 minDebtInBase, uint256 killFactorBps);
    event ChangeSwapHelper(address swapHelper);

    mapping(address => bool) public whitelistedDelegator;
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

    struct Position {
        address user;
        // uint256 equity;
        // uint256 debtInBase;
        /// @dev totalShare * (equity + debtInBase) / totalAmount
        uint256 share;
        uint256 debt;
    }

    /// @dev userAddress => vaultAddress => positionId (array Index of position)
    mapping(address => mapping(address => uint256)) public positionIdOf;
    /// @dev vaultAddress => Position[]
    mapping(address => Position[]) public positions;
    mapping(address => uint256) public positionsLengthOf;

    // debt To Vault
    mapping (address => uint256) public totalDebtOf;

    ISwapHelper public swapHelper;

    /*************
     * Modifiers *
    **************/

    modifier onlyDelegator(){
        require(
            whitelistedDelegator[msg.sender],
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
        address swapHelper_
    ) external onlyInitializing {
        __Ownable_init();
        __ReentrancyGuard_init();

        // @TODO policy
        setConfigs(
            10e18,  // minDebtInBase
            8000    // killFactorBps
        );

        changeSwapHelper(swapHelper_);
    }

    /**********************
     * Operate Functions *
    ***********************/

    function setWhitelistDelegatorStatus(
        address delegator, 
        bool status
    ) public override onlyOwner {
        whitelistedDelegator[delegator] = status;
    }

    function setVault(
        address token, 
        address vault
    ) public override onlyOwner {
        bool isNewVault = (tokenToVault[token] == address(0));

        if(isNewVault)
            emit AddVault(token, vault);
        else {
            require(
                IVault(tokenToVault[token]).totalDebt() == 0,
                "setVault: Debt remains on the existing vault."
            );
            emit ChangeVault(token, vault);
        }

        tokenToVault[token] = vault;
        // push null position
        positions[vault].push(
            Position({
                user: address(0),
                share: 0,
                debt: 0
            })
        );
    }

    function setConfigs(
        uint256 _minDebtInBase,
        uint256 _killFactorBps
    ) public onlyOwner {
        minDebtInBase = _minDebtInBase;
        killFactorBps = _killFactorBps;
        emit ChangeConfigs(_minDebtInBase, _killFactorBps);
    }

    function changeSwapHelper(
      address _newSwapHelper
    ) public onlyOwner {
        swapHelper = ISwapHelper(_newSwapHelper);
        emit ChangeSwapHelper(_newSwapHelper);
    }


    /***********************
     * Private Functions *
    ************************/
    function _swapFromBaseToToken(
        address token,
        uint256 dx,
        uint256 minDy
    ) private returns (uint256 dy){
        dy = swapHelper.exchange{value: dx}(token, BASE_TOKEN, dx, minDy);
    }
    function _swapFromTokenToBase(
        address token,
        uint256 dx,
        uint256 minDy
    ) private returns (uint256 dy){
        SafeToken.safeApprove(token, address(swapHelper), dx);
        // @TODO should check if success
        dy = swapHelper.exchange(token, BASE_TOKEN, dx, minDy);
    }


    /// @dev
    /// In the name of the user, borrow token from the vault.
    /// kor) debtInBase의 양에 해당하는 만큼 debtToken으로 스왑한다.
    function _borrowAndSwapEvmos(
        address user,
        address token,
        address vault,
        uint256 debtInBase
    ) private returns(uint256 debt) {
        // calculate amount to loan
        debt = swapHelper.getDx(token, BASE_TOKEN, debtInBase);

        IVault(vault).loan(user, debt);
        _swapFromTokenToBase(token, debt, debtInBase);
    }


    function _stake(
        address user,
        uint256 amount
    ) private returns (uint256 share) {
        share = amountToShare(amount);
        totalAmount += amount;
        totalShare += share;
        /**
            @TODO
         */
        
        emit Stake(user, amount, share);
    }


    /// @notice
    /**
     * @notice
    kor)
    1) 유저가 unstake 요청을 했을 때 Stayking 컨트랙트에서 즉시 빚을 갚아줄지,
    2) 14일 이후에 유저가 직접 갚도록 해야 할 지

    1번은 구현은 쉬우나 컨트랙트 내에 여유자금이 충분해야 하고,
    우리가 강제로 14일 롱포지션을 갖는 것이기 때문에 EVMOS 가격 급락 시 리스크가 매우 크다.

    2번은 stEVMOS 컨트랙트에 Lock할 때 빚까지 같이 저장해주어야 한다.
    빚이 있으므로 stEVMOS를 transfer & withdraw를 모두 14일 동안 제한학고,
    14일 이후 stEVMOS를 withdraw할 때 빚까지 같이 갚도록 해야 한다.

     */
    function _unstake(
        address user,
        uint256 amount,
        uint256 share
    ) private{
        /** 
            @TODO
            /IMPL/
        */
        totalAmount -= amount;
        totalShare -= share;

        emit Unstake(user, amount, share);
    }

    /// @dev
    /// In the name of the user, borrow token from the vault.
    function _swapAndRepay(
        address user,
        address token,
        address vault,
        uint256 debt
    ) private returns(uint256 repaidInBase) {
        repaidInBase = swapHelper.getDx(BASE_TOKEN, token, debt);
        _swapFromTokenToBase(token, repaidInBase, debt);

        /**
        @TODO
         */
    }

    function _isHealthy(
        address token,
        uint256 share,
        uint256 debt
    ) private view returns(bool) {
        uint256 debtInBase = swapHelper.getDx(BASE_TOKEN, token, debt);
        return debtInBase * 1e4 < shareToAmount(share) * killFactorBps; 
    }

    /******************
     * Util Functions *
    *******************/
    /// @notice 
    /// 유저는 예치하는 시점에 (예치 금액 / totalAmount) * totalShare에 해당하는 share를 받음.
    function amountToShare(
        uint256 amount
    ) public view returns(uint256) {
        return (totalAmount == 0) ? amount :
            (totalShare * amount) / totalAmount;
    }

    function shareToAmount(
        uint256 share
    ) public view returns(uint256) {
        return (totalShare == 0) ? share :
            (totalAmount * share) / totalShare;
    }

    /******************************
     * Interface implementations *
    *******************************/

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
        // @TODO should be tested
        // debtAmount in debtToken (not in EVMOS)
        uint256 debt = _borrowAndSwapEvmos(
            msg.sender,
            debtToken,
            vault,
            debtInBase
        );

        uint256 share = _stake(msg.sender, amount);

        // write new position state
        positions[vault].push(
            Position({
                user: msg.sender,
                share: share,
                debt: debt
            })
        );

        uint256 positionId = positionsLengthOf[vault];
        positionsLengthOf[vault] += 1;
        positionIdOf[msg.sender][vault] = positionId;

        emit AddPosition(msg.sender, vault, equity, debtInBase, debt, share);
    }


    /// @dev remove all position of debtToken vault.
    /// @param debtToken    debtToken Address (not vault address)
    function removePosition(
        address debtToken
    ) public override {
        address vault = tokenToVault[debtToken];
        Position storage p = positions[vault][positionIdOf[msg.sender][vault]];
        require(p.share > 0, "removePosition: No position for this token");

        // 1. check if user can repay debt
        /// @dev amount in EVMOS that user have to repay
        uint256 currentDebtInBase = swapHelper.getDx(
            BASE_TOKEN, 
            debtToken, 
            p.debt
        );

        uint stakedAmount = shareToAmount(p.share);

        require(
            stakedAmount >= currentDebtInBase,
            "removePosition: Bad debt"
        );

        _unstake(msg.sender, stakedAmount, p.share);

        emit RemovePosition(
            msg.sender, 
            vault, 
            stakedAmount - currentDebtInBase, 
            currentDebtInBase, 
            p.debt, 
            p.share
        );

        p.share = 0;
        // kor) debt를 바로 0으로 만들 것인지?
        p.debt = 0;

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
        uint256 extraDebt = _borrowAndSwapEvmos(
            msg.sender,
            debtToken,
            vault,
            extraDebtInBase
        );

        uint256 extraShare = amountToShare(extraDebtInBase);

        // write edited position state
        p.debt += extraDebt;
        p.share += extraShare;

        require(
            _isHealthy(debtToken, p.share, p.debt),
            "addDebt: bad debt, cannot add more debt anymore."
        );

        _stake(msg.sender, extraDebtInBase);

        emit PositionChanged(
            msg.sender, 
            vault, 
            shareToAmount(p.share),
            p.share,
            p.debt
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
        require(p.debt >= repaidDebt, "repayDebt: too much repaid debt");

        SafeToken.safeTransferFrom(
            debtToken,
            msg.sender,
            address(this),
            repaidDebt
        );

        SafeToken.safeApprove(debtToken, vault, repaidDebt);

        IVault(vault).repay(msg.sender, repaidDebt);

        p.debt -= repaidDebt;

        emit PositionChanged(
            msg.sender, 
            vault, 
            shareToAmount(p.share),
            p.share,
            p.debt
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

        _stake(msg.sender, extraEquity);

        p.share += amountToShare(extraEquity);

        emit PositionChanged(
            msg.sender, 
            vault, 
            shareToAmount(p.share),
            p.share,
            p.debt
        ); 
    }


    function isKillable(
        address debtToken,
        uint256 positionId
    ) public override view returns(bool) {
        Position memory p = positions[tokenToVault[debtToken]][positionId];
        return _isHealthy(debtToken, p.share, p.debt);
    }
    
    function kill(
        address debtToken,
        uint256 positionId
    ) public override onlyKiller {
        Position storage p = positions[tokenToVault[debtToken]][positionId];
        require(
            _isHealthy(debtToken, p.share, p.debt), 
            "Kill: still safe position."
        );

        uint256 amount = shareToAmount(p.share);
        /**
            @TODO
            
         */
        _unstake(p.user, amount, p.share);

        /// @TODO
        emit Kill(p.user);
    }

    /***********************
     * Only for Delegator *
     ***********************/
    function delegate(
        uint256 amount
    ) public onlyDelegator override {

    }

    function accrue(
        uint256 amount
    ) payable public onlyDelegator override {

    }
}