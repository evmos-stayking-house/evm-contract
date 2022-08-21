// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "../interface/IUnbondedEvmos.sol";
import "../interface/IVault.sol";
import "../lib/OwnableUpgradeable.sol";
import "../lib/utils/SafeToken.sol";

contract UnbondedEvmos is IUnbondedEvmos, OwnableUpgradeable { 

    event Lock(address account, address vault, uint256 lockedIndex);
    event Unlock(address account, uint256 amount, uint256 returned);
    event Supply(uint256 amount);
    event Withdraw(address account, uint256 amount);
    event UpdateMinterStatus(address account, bool status);
    event UpdateConfigs(uint256 killFactorBps, uint256 liquidateFeeBps);


    mapping(address => bool) public override isMinter;

    string public constant name = "Unstaked EVMOS";
    string public constant symbol = "uEVMOS";
    uint8 public constant decimals = 18;

    /// @notice kor) 필요 없을 수 있다.
    uint256 public killFactorBps;
    uint256 public liquidateFeeBps;

    struct Locked {
        bool received;
        address account;
        address vault;
        uint256 amount;
        uint256 unlockedAt;
    }

    Locked[] public locks;
    uint256 public locksLength;

    /** @dev
     * kor) [논의 필요] Locked[]를 길이가 7인 큐로 지정.
     lockedIds: locks 배열에 들어있는 Lock 객체의 array index
     accounts can request up to 7 unbonds for 14 days, 
     just like when delegate EVMOS to Validator. 
     */
    struct LockedQueue {
        uint128 front;
        uint128 rear;
        uint256[] lockedIds;
    }
    mapping(address => LockedQueue) public lockedOf;
    mapping(address => uint256) _balances;
    uint256 public override totalSupply;

    function __UnbondedEvmos_init(
        address minter_,
        uint256 killFactorBps_,
        uint256 liquidateFeeBps_
    ) external initializer {
        __Ownable_init();
        updateMinterStatus(minter_, true);
        updateConfigs(
            killFactorBps_,
            liquidateFeeBps_
        );
    }

    /**************
        Modifier
     *************/
    modifier onlyMinter(){
        require(isMinter[msg.sender], "uEVMOS: Not minter.");
        _;
    }

    function updateMinterStatus(
        address account,
        bool status
    ) public override onlyOwner {
        isMinter[account] = status;
        emit UpdateMinterStatus(account, status);
    }

    function updateConfigs(
        uint256 _killFactorBps,
        uint256 _liquidateFeeBps
    ) public onlyOwner {
        liquidateFeeBps = _liquidateFeeBps;
        killFactorBps = _killFactorBps;
        emit UpdateConfigs(_killFactorBps, _liquidateFeeBps);
    }

    /*******************
      Private functions
    ********************/
    function _mint(
        address account,
        uint256 amount
    ) private{
        require(account != address(0), "uEVMOS: mint to the zero address");

        totalSupply += amount;
        _balances[account] += amount;
    }

    function _burn(
        address account,
        uint256 amount
    ) private {
        require(account != address(0), "uEVMOS: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "uEVMOS: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        totalSupply -= amount;
    }

    function _repayPendingDebt(
        address account,
        address vault,
        uint256 unlockable,
        uint256 minRepaid
    ) private returns (uint256 restUnlocked) {
        uint256 pendingDebtInBase = IVault(vault).getPendingDebtInBase(account);
        if(unlockable >= pendingDebtInBase){
            IVault(vault).repayInBase{value: pendingDebtInBase}(account, minRepaid);
            return unlockable - pendingDebtInBase;
        }
        else {
            /// @dev kor) 빚을 다 갚을 수 있는지 없는지?
            // case 1. 빚 못 갚으면 revert
            // revert();
            // case 2. 빚 못 갚아도 일단 갚을 수 있는 것만 repay
            IVault(vault).repayInBase{value: unlockable}(account, minRepaid);
            return 0;
        }
    }

    /// @dev unlock all of unlockable uEVMOS
    function _unlock(
        address account,
        LockedQueue storage lockedQueue,
        uint256 minRepaid
    ) private {
        lockedQueue = lockedOf[account];
        uint128 front = lockedQueue.front; 
        uint128 rear = lockedQueue.rear; 

        if(front == rear)   // no unlockable amounts
            return;

        uint256 unlockable;
        uint256 returnable;
        uint128 i = front;
        
        // assert under 7 loop.
        for (i; i < rear; i++) {
            uint256 lockedId = lockedQueue.lockedIds[i];
            Locked memory lock = locks[lockedId];
            
            if(lock.unlockedAt <= block.timestamp){  /// @dev unlockable
                unlockable += lock.amount;

                /// @dev kor) (개선 필요) aggregate하여 repay 횟수 줄이기
                returnable += _repayPendingDebt(
                    account,
                    lock.vault,
                    lock.amount,
                    minRepaid
                );

                locks[lockedId].received = true;
            }
            else 
                break;
        }

        // if unlockable > 0, front < i < rear
        if(unlockable > 0){

            lockedQueue.front = i + 1;           // 1. reset queue front
            _burn(account, unlockable);

            // 3. return EVMOS is returnable exists
            if(returnable > 0){
                SafeToken.safeTransferEVMOS(account, returnable);
            }
            emit Unlock(account, unlockable, returnable);
        }
    }


    /****************** 
       Core Functions
    *******************/
    function balanceOf(
        address account
    ) public view override returns(uint256) {
        return _balances[account];
    }

    function mintLockedToken(
        address to,
        address vault,
        uint256 amount,
        uint256 time
    ) public override onlyMinter {
        require(amount > 0, "mintLockedToken: amount <= 0");

        LockedQueue storage lockedQueue = lockedOf[to];

        /// @dev consume all of unlock queue
        _unlock(to, lockedQueue, 1);

        uint256 unlockedAt = block.timestamp + time;

        locks.push(
            Locked({
                account: msg.sender,
                vault: vault,
                amount: amount,
                unlockedAt: unlockedAt,
                received: false
            })
        );

        locksLength = locks.length - 1;
        uint128 newlockedIndex = lockedQueue.rear;
        lockedQueue.lockedIds[newlockedIndex] = locksLength;

        lockedQueue.rear = newlockedIndex + 1;

        _mint(to, amount);
        emit Lock(to, vault, locksLength);
    }

    // unlock all because of debt.
    function unlock(uint256 minRepaid) public override {
        LockedQueue storage lockedQueue = lockedOf[msg.sender];
        _unlock(msg.sender, lockedQueue, minRepaid);
    }

    function supplyUnbondedToken() payable public override {
        /**
            @TODO
            maybe use delegate/undelegate tx ORACLE?
         */
    }

    /// @dev calc user's unlockable uEVMOS(includes debt) & debt
    function getUnlockable(
        address account
    ) public override view returns(uint256 unlockable, uint256 debt) {
        uint128 front = lockedOf[account].front; 
        uint128 rear = lockedOf[account].rear; 
        uint256[] memory lockedIds = lockedOf[account].lockedIds;

        if(front == rear)   // no unlockable amounts
            return (0, 0);
        
        // assert under 7 loop.
        for (uint128 i = front; i < rear; i++) {
            Locked memory lock = locks[lockedIds[i]];
            if(lock.unlockedAt <= block.timestamp){
                unlockable += lock.amount;

                /// @dev kor) (개선 필요) aggregate하여 repay 횟수 줄이기
                debt += IVault(lock.vault).getPendingDebtInBase(account);
            }
            else 
                break;
        }
    }

    /// @notice TODO
    /// kor) 유저가 일부만 unstake 요청하는 경우, 빚을 다 못 갚는 경우가 당연히 발생한다.
    /// 일단 부채비율이 100% 넘기는 경우 우리가 unlock 시키는 것만 구현.
    function isKillable(uint256 lockedId) public override view returns(bool) {
        Locked memory lock = locks[lockedId];
        if(lock.unlockedAt > block.timestamp)
            return false;
        uint256 debt = IVault(lock.vault).getPendingDebtInBase(lock.account);
        return debt >= lock.amount;
    }

    function kill(uint256 lockedId) public override {
        Locked storage lock = locks[lockedId];
        require(lock.unlockedAt <= block.timestamp, "uEVMOS Kill: Cannot Unlock.");
        uint256 debt = IVault(lock.vault).getPendingDebtInBase(lock.account);
        require(debt >= lock.amount, "uEVMOS Kill: Still safe.");
        
        IVault(lock.vault).repayInBase{value: lock.amount}(lock.account, 1);
        lock.received = true;
        /// @dev event Kill?
    }


    receive() external payable {}

    fallback() external payable {}

}