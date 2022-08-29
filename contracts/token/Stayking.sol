// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "hardhat/console.sol";
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
    event Accrue(address indexed delegator, uint256 totalStaked, uint256 distributed);

    // Operation Events
    event AddVault(address token, address vault);
    event UpdateVault(address token, address vault);
    event UpdateConfigs(uint256 minDebtInBase, uint256 killFactorBps, uint256 reservedBps);
    event ChangeDelegator(address delegator);

    address public delegator;
    mapping(address => bool) public whitelistedKiller;

    mapping(address => address) public override tokenToVault;
    address[] public vaults;

    /// @dev kor) 유저가 예치한 금액 + auto-compound된 금액
    uint256 public totalAmount;
    /// @dev kor) auto-compound되어도 totalShare는 변하지 않음.
    ///  유저는 예치하는 시점에 (예치 금액/totalAmount) * totalShare에 해당하는 share를 받음.
    uint256 public totalShare;

    /// @dev min debtAmount in EVMOS (base token)
    uint256 public override minDebtInBase;
    uint256 public override killFactorBps;
    uint256 public override reservedBps;

    /// @dev EVMOS amount reserved by Protocol
    uint256 public reservedPool;

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
            8000,    // killFactorBps
            3000     // reservedBps
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
        address beforeVault = tokenToVault[token];

        if(beforeVault == address(0)){
            vaults.push(vault);
            emit AddVault(token, vault);
        }
        else {
            require(
                IVault(beforeVault).totalDebtAmount() == 0,
                "updateVault: Debt remains on the existing vault."
            );

            uint256 vaultsLength = vaults.length;
            bool vaultReplaced = false;
            for (uint256 i = 0; i < vaultsLength; i++) {
                if(vaults[i] == beforeVault){
                    vaults[i] = vault;
                    vaultReplaced = true;
                    break;
                }
            }
            assert(vaultReplaced);
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

        positionsLengthOf[vault] = 1;
    }

    function updateConfigs(
        uint256 _minDebtInBase,
        uint256 _killFactorBps,
        uint256 _reservedBps
    ) public onlyOwner {
        minDebtInBase = _minDebtInBase;
        killFactorBps = _killFactorBps;
        reservedBps = _reservedBps;
        emit UpdateConfigs(_minDebtInBase, _killFactorBps, _reservedBps);
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


    /**
     @param p           Position
     @param vault       owed by the user
     @param amount      unstaked amount
     @param repaidDebtInBase  repaid amount in EVMOS ( repaidDebt <= amount = shareToAmount(amount) )
     */
    function _unstake(
        Position storage p,
        address vault,
        uint256 amount,
        uint256 repaidDebtInBase
    ) private {
        require(repaidDebtInBase <= amount, "unstake: repaidDebtInBase > unstaked amount");
        uint256 share = amountToShare(amount);
        p.share -= share;
        totalAmount -= amount;
        totalShare -= share;

        uint256 pendingDebtShare = IVault(vault).pendRepay(p.user, repaidDebtInBase);

        uEVMOS.mintLockedToken(
            p.user,
            vault,
            amount,
            pendingDebtShare
        );

        emit Unstake(delegator, p.user, amount, share);
    }

    function _unstakeAll(
        Position storage p,
        address vault
    ) private returns(uint256 amount){
        uint256 debtInBase = IVault(vault).debtAmountInBase(p.user);
        amount = shareToAmount(p.share);
        _unstake(p, vault, shareToAmount(p.share), debtInBase);
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
        require(positionIdOf[msg.sender][vault] == 0, "addPosition: already have position");
        require(equity == msg.value, "addPosition: msg.value != equity");

        uint256 amount = equity + debtInBase;
        require(
            debtInBase * 1e4 < amount * killFactorBps,
            "addPosition: bad debt, cannot open position"
        );

        // borrow token from vault
        // debtInBase == 0 -> 1x leverage
        uint256 debt = debtInBase > 0 ? 
            IVault(vault).loan(msg.sender, debtInBase) : 0;

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

        uint256 unstakedAmount = _unstakeAll(p, vault);
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
        require(extraDebtInBase > 0, "addDebt: extraDebtInBase <= 0");

        address vault = tokenToVault[debtToken];
        uint256 positionId = positionIdOf[msg.sender][vault];
        require(positionId > 0, "addDebt: no position");

        Position storage p = positions[vault][positionId];

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
        uint256 positionId = positionIdOf[msg.sender][vault];
        require(positionId > 0, "repayDebt: no position");

        Position storage p = positions[vault][positionId];
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
        uint256 positionId = positionIdOf[msg.sender][vault];
        require(positionId > 0, "repayDebtInBase: no position");

        Position storage p = positions[vault][positionId];
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
        uint256 positionId = positionIdOf[msg.sender][vault];
        require(positionId > 0, "addEquity: no position");
        Position storage p = positions[vault][positionId];

        _stake(p, extraEquity);
        emit PositionChanged(
            msg.sender,
            vault,
            shareToAmount(p.share),
            p.share,
            debtAmountOf(msg.sender, vault)
        );
    }

    /** @notice change position value
        case 1. changeEquityInBase > 0 
            - increase position value (call _stake function)
            - decrease debt ratio
        case 2. changeEquityInBase < 0 
            - decrease position value (call _unstake function)
            - increase debt ratio
        case 3. changeDebt > 0 (borrow more debt)
            - increase position value (call _stake function)
            - increase debt ratio
        case 4. changeEquity < 0 (repay debt by unstaking)
            - decrease position value (call _unstake function)
            - decrease debt ratio
        case 5. repayDebt > 0 (repay debt with user's own token) 
                or msg.value > 0 (repay debt with user's own EVMOS)
                @dev (msg.value - changeEquityInBase) equals to repayDebtInBase
            - position value not changes (not call _stake/_unstake function)
            - decrease debt ratio
        @dev User should approve this first
        @dev if msg.value > 0, changeEquityInBase >= 0
             since msg.value = changeEquityInBase + repayDebtInBase
     */
    function changePosition(
        address debtToken,
        int256  equityInBaseChanged,
        int256  debtInBaseChanged,
        uint256 repaidDebt
    ) public payable {
        address vault = tokenToVault[debtToken];
        uint256 positionId = positionIdOf[msg.sender][vault];
        require(positionId > 0, "changePosition: no position");

        uint256 repaidDebtInBase;
        uint256 stakedAmount; // can added if equityInBaseChanged > 0 or  debtInBaseChanged > 0 (add equity or borrow more debt)
        uint256 unstakedAmount;
        if(equityInBaseChanged > 0){    // stake more with own equity
            require(
                msg.value >= uint256(equityInBaseChanged), 
                "changePosition: Not enough msg.value"
            );
            unchecked {
                repaidDebtInBase = msg.value - uint256(equityInBaseChanged);
                stakedAmount = uint256(equityInBaseChanged);
            }
        } 
        else if(equityInBaseChanged < 0) { // partial close position made up of equity
            unstakedAmount = uint256(-equityInBaseChanged);
            // repaidDebtInBase = 0
        }

        if(debtInBaseChanged > 0){ // borrow more debt (stake more)
            IVault(vault).loan(msg.sender, uint256(debtInBaseChanged));
            stakedAmount += uint256(debtInBaseChanged);
        }
        else if(debtInBaseChanged < 0){ // partial close position made up of debt
            unstakedAmount += uint256(-debtInBaseChanged);
        }

        /******************************************
           Repay Debt (position value not change)
         ******************************************/
        if(repaidDebt > 0){ // repay debt for token, approve should be proceed
            SafeToken.safeTransferFrom(debtToken, msg.sender, address(this), repaidDebt);
            IVault(vault).repayInToken(msg.sender, repaidDebt);
        }
        if(repaidDebtInBase > 0){ // repay debt for EVMOS
            repaidDebt += IVault(vault).repayInBase{value: repaidDebtInBase}(msg.sender, 1);
        }

        Position storage p = positions[vault][positionId];
        if(stakedAmount >= unstakedAmount){
            _stake(p, stakedAmount - unstakedAmount);
        } else {
            _unstake(
                p,
                vault,
                unstakedAmount - stakedAmount,
                debtInBaseChanged < 0 ? uint256(-debtInBaseChanged) : 0
            );
        }

        uint256 debtAmount = debtAmountOf(msg.sender, vault);
        (bool healthy, ) = _isHealthy(vault, p.share, debtAmount);
        require(healthy, "changePosition: bad debt");

        emit PositionChanged(
            msg.sender,
            vault,
            shareToAmount(p.share),
            p.share,
            debtAmountOf(msg.sender, vault)
        );
    }

    /**
        @dev returns position's value & debt value
        position value: positionValueInBase
        equity value: positionValueInBase - debtInBase
        debt value: debtInBase
        debt ratio: debtInBase / positionValueInBase * 100(%)
        kill factor: killFactorBps / 100
        safety buffer: (kill factor) - (debt ratio)
     */
    function positionInfo(
        address user,
        address debtToken
    ) public override view returns (uint256 positionValueInBase, uint256 debtInBase, uint256 debt) {
        address vault = tokenToVault[debtToken];
        uint256 positionId = positionIdOf[user][vault];
        Position memory p = positions[vault][positionId];

        positionValueInBase = shareToAmount(p.share);

        debt = IVault(vault).debtAmountOf(user);
        debtInBase = IVault(vault).getBaseIn(debt);
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

        uint256 unstakedAmount = _unstakeAll(p, vault);

        emit Kill(
            msg.sender,
            p.user,
            vault,
            unstakedAmount - debtInBase,
            debtInBase,
            debt,
            p.share
        );

    }

    /***********************
     * Only for Delegator *
     ***********************/
    /// @param totalStaked  current total staked EVMOS (= last total amount + reward)
    function getAccruedValue (
        uint256 totalStaked
    ) public view override returns(uint256) {
        uint256 reward = totalStaked - totalAmount;
        uint256 reserved = reward * reservedBps / 1E4;

        uint256 vaultsLength = vaults.length;
        uint256 interest = 0;
        for(uint256 i = 0; i < vaultsLength; i++){
            interest += IVault(vaults[i]).getInterestInBase();
        }

        return reserved + interest;
    }

    /// @dev msg.value = all of staking reward 
    /// @param totalStaked  current total staked EVMOS before distributed
    function accrue(
        uint256 totalStaked
    ) payable public onlyDelegator override {

        // 1. distribute to Protocol
        uint256 reserved = (totalStaked - totalAmount) * reservedBps / 1E4;
        reservedPool += reserved;

        uint256 sumInterests = 0;
        uint256 vaultsLength = vaults.length;
        /// @dev save interest for each vault
        uint256[] memory interestFor = new uint256[](vaultsLength);
        for(uint256 i = 0; i < vaultsLength; i++){
            interestFor[i] = IVault(vaults[i]).getInterestInBase();
            sumInterests += interestFor[i];
        }

        /// @dev most case, all of staking reward >= vault interests + reserved
        uint256 distributable = msg.value - reserved;
        if(distributable >= sumInterests){
            for(uint256 i = 0; i < vaultsLength; i++){
                IVault(vaults[i]).payInterest{value: interestFor[i]}(
                    IVault(vaults[i]).accInterest()
                );
            }

            totalAmount = totalStaked - reserved - sumInterests;

            // return remained EVMOS
            uint256 remained = msg.value - reserved - sumInterests;
            if(remained > 0){
                SafeToken.safeTransferEVMOS(msg.sender, remained);
            }

            emit Accrue(msg.sender, totalStaked, reserved + sumInterests);
        }
    /**
        @dev
        else case is when the sum of interest for vaults is insufficient.
        this case, totalAmount not changes
        */
        else {  
            for(uint256 i = 0; i < vaultsLength; i++){
                IVault vault = IVault(vaults[i]);
                uint256 interestInBase = interestFor[i] * distributable / sumInterests;
                uint256 minPaidInterest = vault.getTokenOut(interestInBase);
                vault.payInterest{value: interestInBase}(minPaidInterest);
            }

            emit Accrue(msg.sender, totalStaked, msg.value);
        }
    }

    /// @dev Fallback function to accept EVMOS.
    receive() external payable {}

    fallback() external payable {}
}
