// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../interface/IStayking.sol";
import "../interface/IVault.sol";
import "../interface/ISwapHelper.sol";
import "../lib/utils/SafeToken.sol";
import "../lib/OwnableUpgradeable.sol";
import "../lib/ReentrancyGuardUpgradeable.sol";

contract Stayking is IStayking, OwnableUpgradeable, ReentrancyGuardUpgradeable {

    constant address BASE_TOKEN = address(0);

    event Stake(address user, uint256 equity, uint256 debtInBase);
    event Unstake(address user, uint256 equity, uint256 debtInBase);
    event AddPosition(address user, uint256 equity, uint256 debtInBase, address vault, uint256 debt);
    event RemovePosition(address user, uint256 equity, uint256 debtInBase, address vault, uint256 debt);
    event AddEquity(address user, uint256 amount);
    event RemoveEquity(address user, uint256 amount);
    event AddDebt(address user, uint256 debtInBase, address vault, uint256 debt);
    event RepayDebt(address user, uint256 debtInBase, address vault, uint256 debt);
    event Accrue(address delegator, uint256 amount);

    // Operation Events
    event AddVault(address token, address vault);
    event ChangeVault(address token, address vault);
    event ChangeConfigs(uint256 minDebtInBase, uint256 killFactorBps);
    event ChangeSwapHelper(address swapHelper);

    mapping(address => bool) public whitelistedDelegator;
    mapping(address => address) public override tokenToVault;

    uint256 totalStaked;

    /// @dev min debtAmount in EVMOS (base token)
    uint256 public minDebtInBase;
    uint256 public killFactorBps;

    struct Position {
        address user;
        uint256 equity;
        uint256 debtInBase;
        uint256 debt;
        uint256 lastHarvestedAt;
    }

    /// @dev userAddress => vaultAddress => positionId (array Index of position)
    mapping(address => mapping(address => uint256)) public positionIdOf;
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
                IVault(tokenToVault[token]).totalDebt == 0,
                "setVault: Debt remains on the existing vault."
            )
            emit ChangeVault(token, vault);
        }

        tokenToVault[token] = vault;
        // push null position
        positions[vault].push({
            user: address(0),
            equity: 0,
            debtInBase: 0,
            debt: 0,
            lastHarvestedAt: 0
        });
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
        uint256 minDy,
    ) private returns (uint256 dy){
        dy = swapHelper.exchange{value: dx}(from, BASE_TOKEN, debt, minDy);
    }
    function _swapFromTokenToBase(
        address token,
        uint256 dx,
        uint256 minDy,
    ) private returns (uint256 dy){
        SafeToken.safeApprove(from, address(swapHelper), dx);
        // should check if success
        dy = swapHelper.exchange(from, BASE_TOKEN, debt, minDy);
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
        uint256 repayDebt
    ) private returns (uint256 lockedstEVMOS){
        // uint256 repayDebtInBase = 
        /** 
            @TODO
            /IMPL/
        */
        emit Unstake(user, uint256 equity, uint256 debtInBase);
    }

    /// @dev
    /// In the name of the user, borrow token from the vault.
    function _swapAndRepay(
        address user,
        address token,
        address vault,
        uint256 debt
    ) private returns(uint256 repaidInBase) {
        repaidInBase = IVault(vault).getDx(BASE_TOKEN, token, debt);
        _swap(token, BASE_TOKEN, repaidInBase, debt);
    }

    function _harvest(
        address user,
        address vault
    ) private {
        // @TODO IMPL
        positions[vault].lastHarvestedAt = block.timestamp;
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
    ) public payable {
        address vault = tokenToVault[debtToken];
        require(positionIdOf[msg.sender][vault] > 0, "addPosition: already have position");
        require(equity == msg.value, "addPosition: msg.value != equity");
        require(
            debtInBase * 1e4 < (equity + debtInBase) * killFactorBps,
            "addPosition: bad debt, cannot open position"
        )

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
        positions[vault].push({
            user: msg.sender,
            equity: equity,
            debtInBase: debtInBase,
            debt: debt,
            lastHarvestedAt: block.timestamp
        });
        uint256 positionId = positionsLength;
        positionsLengthOf[vault] += 1;
        positionIdOf[msg.sender][vault] = positionId;

        totalStaked += (equity + debtInBase);

        emit AddPosition(msg.sender, equity, debtInBase, vault, debt);
    }


    /// @dev remove all position of debtToken vault.
    /// @param debtToken    debtToken Address (not vault address)
    function removePosition(
        uint256 debtToken
    ) public {
        address vault = tokenToVault[debtToken];

        // harvest all interests before remove position
        _harvest(msg.sender, vault);

        Position storage p = positions[positionIdOf[msg.sender][vault]];
        require(p.equity > 0, "removeLiquidity: No position for this token");

        // 1. check if user can repay debt
        /// @dev amount in debtToken that user have to repay
        uint256 currentDebtInBase = swapHelper.getDx(
            BASE_TOKEN, 
            debtToken, 
            p.debt
        );
        require(
            currentDebtInBase =< (p.debtInBase + p.equity),
            "removeLiquidity: Bad debt"
        );

        // @TODO
        _unstake(msg.sender, debtToken, p.debt);

        positionIdOf[msg.sender][vault] = 0; // kor) positionId 초기화
        totalStaked -= (p.debtInBase + p.equity);
        emit RemovePosition(msg.sender, p.equity, p.debtInBase, vault, p.debt);
    }

    /// @dev Increase debt ratio of position.
    /// @param debtToken    debtToken Address (not vault address)
    /// @param extraEquity  amount of additional equity
    /// @param extraDebtInBase  amount of additional debt in EVMOS
    function increasePositionDebt(
        address debtToken,
        uint256 extraDebtInBase
    ) public {
        address vault = tokenToVault[debtToken];
        
        // harvest all interests before remove position
        _harvest(msg.sender, vault);
        Position storage p = positions[positionIdOf[msg.sender][vault]];

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
            "increasePositionDebt: bad debt, cannot open position"
        )

        // @TODO check position is healthy

        uint256 positionId = positionsLength;
        positionsLengthOf[vault] += 1;
        positionIdOf[msg.sender][vault] = positionId;

        totalStaked += extraDebtInBase;
    };

    /// @dev Decrease debt ratio by repaying debt or increase equity.
    /// @notice you can repay debt by baseToken(EVMOS) or debtToken.
    /// @param debtToken    debtToken Address (not vault address)
    /// @param extraEquity  amount of additional equity
    /// @param extraDebt  amount of additional debt in debtToken
    /// @param extraDebtInBase  amount of additional debt in EVMOS
    function decreasePositionDebt(
        address debtToken,
        uint256 extraEquity,
        uint256 extraDebt,
        uint256 extraDebtInBase
    ) payable public {
        address vault = tokenToVault[debtToken];

        // harvest all interests before remove position
        _harvest(msg.sender, vault);
        Position storage p = positions[positionIdOf[msg.sender][vault]];

        // @TODO
    };

    // function changePosition(
    //     address debtToken,
    //     uint256 extraEquity,
    //     uint256 repayDebtInBase,
    //     uint256 extraDebtInBase
    // ) payable public {
    //     address vault = tokenToVault[debtToken];

    //     // harvest all interests before remove position
    //     _harvest(msg.sender, vault);

    //     Position storage p = positions[positionIdOf[msg.sender][vault]];

    //     uint256 equityAdded;
    //     uint256 debtAdded;
    //     uint256 debtInBaseAdded;
    //     uint256 debtRepaid;
    //     uint256 debtInBaseRepaid;

    //     //@TODO
    //     // 1. add extra equity
    //     if(extraEquity > 0){
    //         //@TODO
    //         require(
    //             msg.value == extraEquity,
    //             "changePosition: msg.value != extraEquity"
    //         );
    //         equityAdded += extraEquity;
    //     }
    //     // 2. repay debt
    //     if(repayDebtInBase > 0){
    //         //@TODO
    //         _swapAndRepay(
    //             msg.sender,
    //             debtToken,
    //             vault,
    //             uint256 debt,
    //             uint256 minDy
    //         ) 
    //         equityAdded += repayDebtInBase;


    //     }

    //     // 3. extra debt in base
    //     if(repayDebtInBase > 0){
    //         equityAdded += extraEquity;
    //         //@TODO
    //     }
        
    // }

    /// @dev harvest(claim)할 수 있도록할지? 아니면 only auto-compound?
    function harvest(address debtToken) public {
        address vault = tokenToVault[debtToken];
        // harvest all interests before remove position
        _harvest(msg.sender, vault);
    }


    function isKillable(
        uint256 positionId
    ) public view returns(bool) {
        
    };
    
    function kill(uint256 positionId) external;

    /***********************
     * Only for Delegator *
     ***********************/
    function delegate(uint256 amount) external;

    function accrue(uint256 amount) payable external;
}