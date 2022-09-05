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
    event Accrue(address indexed delegator, uint256 accrued, uint256 totalStaked);

    // Operation Events
    event AddVault(address token, address vault);
    event UpdateVault(address token, address vault);
    event UpdateConfigs(uint256 minDebtInBase, uint256 reservedBps, uint256 killFactorBps, uint256 liquidateDebtFactorBps);
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
    uint256 public override reservedBps;
    uint256 public override killFactorBps;
    uint256 public override liquidateDebtFactorBps;

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
        // todo
        liquidateDebtFactorBps = 10000;

        __Ownable_init();
        __ReentrancyGuard_init();

        // @TODO policy
        updateConfigs(
            1e16,     // minDebtInBase (10EVMOS)
            3000,     // reservedBps
            7500,     // killFactorBps
            7500      // liquidateDebtFactorBps
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
        uint256 _reservedBps,
        uint256 _killFactorBps,
        uint256 _liquidateDebtFactorBps
    ) public onlyOwner {
        minDebtInBase = _minDebtInBase;
        reservedBps = _reservedBps;
        killFactorBps = _killFactorBps;
        liquidateDebtFactorBps = _liquidateDebtFactorBps;
        emit UpdateConfigs(_minDebtInBase, _reservedBps, _killFactorBps, _liquidateDebtFactorBps);
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
     @param repaidDebt  repaid amount in token
     
     @notice
     kor) Unstake할 때, 가격변동 + 대출이자로 인해 빚이 늘어나는 것에 대비하여
     자기자본도 일부 unstake해야 한다.
     TODO 그 기준은 일단 killFactor로 한다.
     */
    function _unstake(
        Position storage p,
        address vault,
        uint256 amount,
        uint256 repaidDebt
    ) private {
        uint256 share = amountToShare(amount);
        p.share -= share;
        totalAmount -= amount;
        totalShare -= share;

        uint256 pendingDebtShare = repaidDebt > 0 ? IVault(vault).pendRepay(p.user, repaidDebt) : 0;

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
        uint256 debt = IVault(vault).debtAmountOf(p.user);
        amount = shareToAmount(p.share);
        _unstake(p, vault, amount, debt);
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

    function abs(int x) private pure returns (int) {
        return x >= 0 ? x : -x;
    }
    function _adjustChangePositionArgs(
        int256 equityInBaseChanged,
        int256 debtInBaseChanged
    ) private pure returns (bool isStaking, uint256 equity, uint256 debtInBase, int256 repaidDebtChanged){

        // kor) 논의 필요
        require(
            equityInBaseChanged * debtInBaseChanged >= 0, 
            "equityInBaseChanged * debtInBaseChanged < 0"
        );

        // equityInBaseChanged * debtInBaseChanged < 0 케이스 가능한 경우
        // 불가능한 경우 repaidDebtChanged 고려하지 않아도 됨.
        if(equityInBaseChanged * debtInBaseChanged < 0){        // current, unreachable
            bool isAddingEquity = equityInBaseChanged > 0;
            equity = uint256(abs(equityInBaseChanged));
            debtInBase = uint256(abs(debtInBaseChanged));

            (isStaking, equity, debtInBase, repaidDebtChanged) = equity > debtInBase ?
                (
                    isAddingEquity, 
                    equity - debtInBase, 
                    uint256(0), 
                    isAddingEquity ? int(debtInBase) : -int(debtInBase)
                ) :
                (
                    !isAddingEquity, 
                    uint256(0), 
                    debtInBase - equity, 
                    isAddingEquity ? int(equity) : -int(equity)
                );
        }
        else {
            equity = uint256(abs(equityInBaseChanged));
            debtInBase = uint256(abs(debtInBaseChanged));
            isStaking = (equityInBaseChanged > 0 || debtInBaseChanged > 0);
        }
    }
    /** @notice change position value
        case 1. equityInBaseChanged > 0 
            - increase position value (call _stake function)
            - decrease debt ratio
        case 2. equityInBaseChanged < 0 
            - decrease position value (call _unstake function)
            - increase debt ratio
        case 3. debtInBaseChanged > 0 (borrow more debt)
            - increase position value (call _stake function)
            - increase debt ratio
        case 4. debtInBaseChanged < 0 (repay debt by unstaking)
            - decrease position value (call _unstake function)
            - decrease debt ratio
        case 5. repaidDebt > 0 or repaidDebtInBase > 0 (repay debt with user's own token/EVMOS) 
            - position value not changes (not call _stake/_unstake function)
            - decrease debt ratio
        @dev repayDebtInBase = msg.value - changeEquityInBase
        @dev User should approve this first
        @dev if msg.value > 0, changeEquityInBase >= 0
             since msg.value = changeEquityInBase + repayDebtInBase
        @notice 
        If equityInBaseChanged > 0 and debtInBaseChanged < 0, it is inefficient.
            e.g. A = 100 and B = -50, 50 EVMOS is Locked at uEVMOS.
            it produces the same result as if A = 50 and C = 50.
        (both increases equity by 50 EVMOS and repay debt by 50 EVMOS)
        Similarly, the case where equityInBaseChanged < 0 and debtInBaseChanged > 0 are also inefficient.
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

        Position storage p = positions[vault][positionId];

        uint256 repaidDebtInBase;
        if(equityInBaseChanged >= 0){    // stake more with own equity
            require(
                msg.value >= uint256(equityInBaseChanged), 
                "changePosition: Not enough msg.value"
            );
            unchecked {
                repaidDebtInBase = msg.value - uint256(equityInBaseChanged);
            }
        } 

        (
            bool isStaking, 
            uint256 equity, 
            uint256 debtInBase, 
            int256 repaidDebtChanged
        ) = _adjustChangePositionArgs(equityInBaseChanged, debtInBaseChanged);

        if(repaidDebtChanged >= 0){
            repaidDebtInBase += uint256(repaidDebtChanged);
        }
        else {
            if(repaidDebtInBase >= uint256(-repaidDebtChanged)){
                repaidDebtInBase -= uint256(-repaidDebtChanged);
            }
            else {
                repaidDebtInBase = 0;
                repaidDebtChanged += int(repaidDebtInBase);
            }
        }

        if(isStaking){
            if(debtInBase > 0){
                IVault(vault).loan(msg.sender, debtInBase);
            }
            _stake(p, equity + debtInBase);
        }
        else {
            // TODO repaidDebtChanged ?
            uint256 unstakedAmount = equity + debtInBase + (repaidDebtChanged < 0 ? uint256(-repaidDebtChanged) : 0);
            require(
                debtInBase * 1E4 <= unstakedAmount * liquidateDebtFactorBps,
                "unstake: too much debt in unstaked EVMOS"
            );

             _unstake(
                p,
                vault,
                unstakedAmount,
                IVault(vault).getBaseOut(debtInBase)
            );
        }

        /******************************************
           Repay Debt (position value not change)
         ******************************************/
        if(repaidDebt > 0){ // repay debt for token, approve should be proceed
            SafeToken.safeTransferFrom(debtToken, msg.sender, address(this), repaidDebt);
            IVault(vault).repayInToken(msg.sender, repaidDebt);
        }
        if(repaidDebtInBase > 0){ // repay debt for EVMOS
            IVault(vault).repayInBase{value: repaidDebtInBase}(msg.sender, 1);
        }

        {
            uint256 debtAmount = debtAmountOf(msg.sender, vault);
            (bool healthy, ) = _isHealthy(vault, p.share, debtAmount);
            require(healthy, "changePosition: bad debt");
        }

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
    ) public override view returns(bool) {
        address vault = tokenToVault[debtToken];
        Position memory p = positions[vault][positionId];

        if(p.share == 0)    /// @dev removed position
            return false;
        (bool healthy, ) = _isHealthy(vault, p.share, debtAmountOf(p.user, vault));
        return !healthy;
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
    /// @param reward  claimed staking reward
    function getAccruedValue (
        uint256 reward
    ) public view override returns(uint256) {
        uint256 reserved = reward * reservedBps / 1E4;

        uint256 vaultsLength = vaults.length;
        uint256 interest = 0;
        for(uint256 i = 0; i < vaultsLength; i++){
            interest += IVault(vaults[i]).getInterestInBase();
        }

        return reward - (reserved + interest);
    }

    /// @dev msg.value = all of staking reward 
    /// @param totalStaked  current total staked EVMOS (except staking reward)
    function accrue(
        uint256 totalStaked
    ) payable public onlyDelegator override {
        require(totalStaked >= totalAmount, "totalStaked < before totalAmount");

        // 1. distribute to Protocol
        uint256 reserved = msg.value * reservedBps / 1E4;
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

            // return remained EVMOS to auto-compound
            uint256 accrued = distributable - sumInterests;
            totalAmount += accrued;

            if(accrued > 0){
                SafeToken.safeTransferEVMOS(msg.sender, accrued);
            }

            emit Accrue(msg.sender, accrued, totalAmount);
        }
    /**
        @dev
        else case is when the sum of interest for vaults is insufficient.
        this case, totalAmount not changes (totalAmount = totalStaked)
        */
        else {  
            for(uint256 i = 0; i < vaultsLength; i++){
                IVault vault = IVault(vaults[i]);
                uint256 interestInBase = interestFor[i] * distributable / sumInterests;
                uint256 minPaidInterest = vault.getTokenOut(interestInBase);
                vault.payInterest{value: interestInBase}(minPaidInterest);
            }

            emit Accrue(msg.sender, 0, totalAmount);
        }
    }

    /// @dev Fallback function to accept EVMOS.
    receive() external payable {}

    fallback() external payable {}
}
