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

    event Stake(address user, uint256 equity, uint256 debtInBase);
    event Unstake(address user, uint256 equity, uint256 debtInBase);
    event AddPosition(address user, uint256 equity, uint256 debtInBase, address vault, uint256 debt);
    event RemovePosition(address user, uint256 equity, uint256 debtInBase, address vault, uint256 debt);
    event AddEquity(address user, uint256 amount);
    event RemoveEquity(address user, uint256 amount);
    event AddDebt(address user, address vault, uint256 debt, uint256 debtInBase);
    event RepayDebt(address user, address vault, uint256 debt, uint256 debtInBase);
    event Accrue(address delegator, uint256 amount);

    // Operation Events
    event AddVault(address token, address vault);
    event ChangeVault(address token, address vault);
    event ChangeConfigs(uint256 minDebtInBase, uint256 killFactorBps);
    event ChangeSwapHelper(address swapHelper);

    mapping(address => bool) public whitelistedDelegator;
    mapping(address => bool) public whitelistedKiller;

    mapping(address => address) public override tokenToVault;

    uint256 totalStaked;

    /// @dev min debtAmount in EVMOS (base token)
    uint256 public override minDebtInBase;
    uint256 public override killFactorBps;

    struct Position {
        address user;
        uint256 equity;
        uint256 debtInBase;
        uint256 debt;
        uint256 lastHarvestedAt;
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
                equity: 0,
                debtInBase: 0,
                debt: 0,
                lastHarvestedAt: 0
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
        address token,
        uint256 equity,
        uint256 debtInBase
    ) private {
        /**
            @TODO
         */
        totalStaked += (equity + debtInBase);
        
        emit Stake(user, equity, debtInBase);

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
        address token,
        uint256 equity,
        uint256 debtInBase
    ) private returns (uint256 lockedstEVMOS){
        /** 
            @TODO
            /IMPL/
        */
        
        totalStaked -= (equity + debtInBase);

        emit Unstake(user, equity, debtInBase);

        // @TODO to be changed
        lockedstEVMOS = equity;
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
    }

    function _harvest(
        address user,
        address vault
    ) private {
        // @TODO IMPL
        // positions[vault].lastHarvestedAt = block.timestamp;
    }

    function _isHealty(
        uint256 equity,
        address token,
        uint256 debt
    ) private view returns(bool) {
        uint256 debtInBase = swapHelper.getDx(BASE_TOKEN, token, debt);
        return debtInBase * 1e4 < (equity + debtInBase) * killFactorBps; 
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
        require(
            debtInBase * 1e4 < (equity + debtInBase) * killFactorBps,
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

        // write new position state
        positions[vault].push(
            Position({
                user: msg.sender,
                equity: equity,
                debtInBase: debtInBase,
                debt: debt,
                lastHarvestedAt: block.timestamp
            })
        );
        uint256 positionId = positionsLengthOf[vault];
        positionsLengthOf[vault] += 1;
        positionIdOf[msg.sender][vault] = positionId;

        _stake(
            msg.sender,
            debtToken,
            equity,
            debtInBase
        );

        emit AddPosition(msg.sender, equity, debtInBase, vault, debt);
    }


    /// @dev remove all position of debtToken vault.
    /// @param debtToken    debtToken Address (not vault address)
    function removePosition(
        address debtToken
    ) public override {
        address vault = tokenToVault[debtToken];
        Position storage p = positions[vault][positionIdOf[msg.sender][vault]];
        require(p.equity > 0, "removeLiquidity: No position for this token");

        // 1. check if user can repay debt
        /// @dev amount in EVMOS that user have to repay
        uint256 currentDebtInBase = swapHelper.getDx(
            BASE_TOKEN, 
            debtToken, 
            p.debt
        );

        require(
            (p.debtInBase + p.equity) >= currentDebtInBase,
            "removeLiquidity: Bad debt"
        );

        // harvest all interests before remove position
        _harvest(msg.sender, vault);

        // @TODO
        _unstake(msg.sender, debtToken, p.equity, p.debtInBase);

        p.equity = 0;
        // kor) debt를 바로 0으로 만들 것인지?
        p.debt = 0;
        p.debtInBase = 0;

        positionIdOf[msg.sender][vault] = 0; // kor) positionId 초기화
        totalStaked -= (p.debtInBase + p.equity);
        emit RemovePosition(msg.sender, p.equity, p.debtInBase, vault, p.debt);
    }

    /// @dev Increase debt ratio of position.
    /// @param debtToken    debtToken Address (not vault address)
    /// @param extraDebtInBase  amount of additional debt in EVMOS
    function addDebt(
        address debtToken,
        uint256 extraDebtInBase
    ) public override {
        address vault = tokenToVault[debtToken];        
        // harvest all interests before edit position
        _harvest(msg.sender, vault);
        Position storage p = positions[vault][positionIdOf[msg.sender][vault]];

        require(p.equity > 0, "increasePositionDebt: no position in for this token.");
        require(extraDebtInBase > 0, "increasePositionDebt: extraDebtInBase <= 0");

        // borrow token from vault
        uint256 extraDebt = _borrowAndSwapEvmos(
            msg.sender,
            debtToken,
            vault,
            extraDebtInBase
        );

        // write edited position state
        p.debt += extraDebt;
        p.debtInBase += extraDebtInBase;

        require(
            _isHealty(p.equity, debtToken, p.debtInBase),
            "addDebt: bad debt, cannot add more debt anymore."
        );

        _stake(
            msg.sender,
            debtToken,
            0,
            extraDebtInBase
        );

        uint256 positionId = positionsLengthOf[vault];
        positionsLengthOf[vault] += 1;
        positionIdOf[msg.sender][vault] = positionId;

        totalStaked += extraDebtInBase;

        emit AddDebt(msg.sender, vault, extraDebt, extraDebtInBase);
    }

    /// @dev Repay debt (decrease debt ratio, total staked amount not changes.)
    /// @notice user should repay debt using debtToken
    /// @notice user approve should be preceded
    /// @param debtToken    debtToken Address (not vault address)
    /// @param repaidDebt  amount of repaid debt in debtToken
    function repayDebt(
        address debtToken,
        uint256 repaidDebt
    ) public override {
        address vault = tokenToVault[debtToken];        
        // harvest all interests before edit position
        _harvest(msg.sender, vault);
        Position storage p = positions[vault][positionIdOf[msg.sender][vault]];
        require(p.equity > 0, "increasePositionDebt: no position in for this token.");

        require(
            p.debt >= repaidDebt, "repayDebt: too much repaid debt"
        );

        /// @dev kor) 
        /// 실제 가격이 아닌 전체 빚 중 갚은 빚의 비율만큼 
        /// repaidDebtInBase이 산정된다.
        uint256 repaidDebtInBase = repaidDebt * p.debtInBase / p.debt;

        SafeToken.safeTransferFrom(
            debtToken,
            msg.sender,
            address(this),
            repaidDebt
        );

        SafeToken.safeApprove(
            debtToken,
            vault,
            repaidDebt
        );

        IVault(vault).repay(
            msg.sender,
            repaidDebt
        );

        p.debt -= repaidDebt;
        p.debtInBase -= repaidDebtInBase;
        p.equity += repaidDebtInBase;

        require(
            _isHealty(p.equity, debtToken, p.debtInBase),
            "repayDebt: bad debt, cannot repay debt"
        );

        emit RepayDebt(msg.sender, vault, repaidDebt, repaidDebtInBase);
    }


    /// @dev add additional equity (decrease debt ratio)
    /// @param debtToken    debtToken Address (not vault address)
    /// @param extraEquity  amount of additional equity
    function addEquity(
        address debtToken,
        uint256 extraEquity
    ) payable public override {
        address vault = tokenToVault[debtToken];        
        // harvest all interests before edit position
        _harvest(msg.sender, vault);
        Position storage p = positions[vault][positionIdOf[msg.sender][vault]];

        p.equity += extraEquity;

        _stake(
            msg.sender,
            debtToken,
            extraEquity,
            0
        );

        require(
            _isHealty(p.equity, debtToken, p.debtInBase),
            "addEquity: bad debt, cannot add equity."
        );
    }


    /// @dev harvest(claim)할 수 있도록할지? 아니면 only auto-compound?
    function harvest(address debtToken) public {
        address vault = tokenToVault[debtToken];
        // harvest all interests before remove position
        _harvest(msg.sender, vault);
    }


    function isKillable(
        uint256 positionId
    ) public override view returns(bool) {
        return false;
    }
    
    function kill(
        uint256 positionId
    ) public override onlyKiller {
        require(isKillable(positionId), "Kill: still safe position.");
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