// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "../interface/IUnbondedEvmos.sol";
import "../interface/IVault.sol";
import "../lib/OwnableUpgradeable.sol";
import "../lib/ERC20Upgradeable.sol";
import "../lib/utils/SafeToken.sol";
import "hardhat/console.sol";

contract UnbondedEvmos is IUnbondedEvmos, OwnableUpgradeable, ERC20Upgradeable { 

    event Lock(address account, address vault, uint256 lockedIndex);
    event Unlock(address account, uint256 amount, uint256 returned);
    event Supply(uint256 amount);
    event Withdraw(address account, uint256 amount);
    event UpdateMinterStatus(address account, bool status);
    event UpdateConfigs(uint256 unbondingInterval);

    mapping(address => bool) public override isMinter;

    uint256 public override lastUnbondedAt;
    uint256 public override unbondingInterval;   // maybe 14 + 2 days

    /// @dev unbondLimit?
    // uint256 public unbondLimit = 7;

    struct Locked {
        bool received;
        address account;
        address vault;
        uint256 amount;
        uint256 debtShare;
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
        uint256 nextUnlocked;
        uint256[] lockedIds;
    }
    mapping(address => LockedQueue) public lockedOf;
    mapping(address => uint256) _balances;

    /// @notice should set minter (maybe Stayking) after deployed
    function __UnbondedEvmos_init(
        uint256 unbondingInterval_
    ) external initializer {
        __Ownable_init();
        __ERC20_init(
            "Unstaked EVMOS", // name
            "uEVMOS" //symbol
        );
        updateConfigs(unbondingInterval_);
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
        uint256 _unbondingInterval
    ) public onlyOwner {
        unbondingInterval = _unbondingInterval;
        emit UpdateConfigs(_unbondingInterval);
    }


    /// @return unlocked     total unlocked EVMOS
    /// @return restUnlocked EVMOS amount that user can receive
    function _repayPendingDebt(
        Locked storage lock,
        uint256 minRepaid
    ) private returns (uint256, uint256) {
        IVault vault = IVault(lock.vault);
        address account = lock.account;
        uint256 amount = lock.amount;

        uint256 pendingDebtInBase = vault.pendingDebtShareToAmount(lock.debtShare);
        lock.received = true;
        if(amount >= pendingDebtInBase){
            IVault(vault).repayInBase{value: pendingDebtInBase}(account, minRepaid);
            return (amount, amount - pendingDebtInBase);
        }
        else {
            vault.repayInBase{value: amount}(account, minRepaid);
            return (amount, 0);
        }
    }

    /// @dev unlock all of unlockable uEVMOS
    function _unlock(
        address account,
        LockedQueue storage lockedQueue,
        uint256 minRepaid
    ) private {
        lockedQueue = lockedOf[account];
        uint256 nextUnlocked = lockedQueue.nextUnlocked; 
        uint256 queueLength = lockedQueue.lockedIds.length;

        if(nextUnlocked >= queueLength)   // no unlockable amounts
            return;

        uint256 unlockable;
        uint256 returnable;
        uint256 i = nextUnlocked;
        
        // assert under 7 loop.
        for (i; i < queueLength; i++) {
            uint256 lockedId = lockedQueue.lockedIds[i];
            Locked storage lock = locks[lockedId];
            
            if(lock.unlockedAt <= block.timestamp){  /// @dev unlockable
                unlockable += lock.amount;

                /// @dev kor) (개선 필요) aggregate하여 repay 횟수 줄이기
                (uint256 unlocked, uint256 returned) = _repayPendingDebt(
                    lock,
                    minRepaid
                );
                unlockable += unlocked;
                returnable += returned;
            }
            else 
                break;
        }

        if(unlockable > 0){
            lockedQueue.nextUnlocked = i + 1;           // 1. reset queue front
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
    function transfer(
        address to,
        uint256 amount
    ) public override onlyMinter returns (bool){
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override onlyMinter returns (bool){
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function lockedList(
        address account
    ) public view returns(Locked[] memory accountLocks){
        LockedQueue memory lockedQueue = lockedOf[account];
        uint256[] memory lockedIds = lockedQueue.lockedIds;

        uint256 queueLength = lockedIds.length;
        if(queueLength == 0){
            return new Locked[](0);
        }

        uint256 first = lockedQueue.nextUnlocked;
        uint256 length = queueLength - first;
        accountLocks = new Locked[](length);

        for(uint256 i = 0; i < length ; i++){
            Locked memory locked = locks[lockedIds[i + first]];
            accountLocks[i] = locked;
        }

        return accountLocks;
    }


    /// @dev mint & lock uEVMOS
    ///
    function mintLockedToken(
        address to,
        address vault,
        uint256 amount,
        uint256 debtShare
    ) public override onlyMinter {
        require(amount > 0, "mintLockedToken: amount <= 0");

        LockedQueue storage lockedQueue = lockedOf[to];

        /// @dev consume all of unlock queue
        _unlock(to, lockedQueue, 1);

        /// @dev limit queue size?
        // require(lockedQueue.rear - lockedQueue.front < unbondLimit, "mintLockedToken: unbond limit exceeded." );
        locks.push(
            Locked({
                account: msg.sender,
                vault: vault,
                amount: amount,
                debtShare: debtShare,
                // TODO 개선 필요
                unlockedAt: (
                    lastUnbondedAt > block.timestamp ? lastUnbondedAt : block.timestamp
                ) + unbondingInterval,
                received: false
            })
        );

        uint256 newLockedId = locks.length - 1;
        lockedQueue.lockedIds.push(newLockedId);

        _mint(to, amount);
        emit Lock(to, vault, newLockedId);
    }

    // unlock all because of debt.
    function unlock(uint256 minRepaid) public override {
        LockedQueue storage lockedQueue = lockedOf[msg.sender];
        _unlock(msg.sender, lockedQueue, minRepaid);
    }

    function supplyUnbondedToken() payable public override {
        lastUnbondedAt = block.timestamp;
        emit Supply(msg.value);
    }

    /// @dev calc user's unlockable uEVMOS(includes debt) & debt
    function getUnlockable(
        address account
    ) public override view returns(uint256 unlockable, uint256 debt) {
        uint256 nextUnlocked = lockedOf[account].nextUnlocked; 
        uint256 queueLength = lockedOf[account].lockedIds.length; 
        uint256[] memory lockedIds = lockedOf[account].lockedIds;

        if(nextUnlocked == queueLength)   // no unlockable amounts
            return (0, 0);
        
        // TODO assert under 7 loop?
        for (uint256 i = nextUnlocked; i < queueLength; i++) {
            Locked memory lock = locks[lockedIds[i]];
            if(lock.unlockedAt <= block.timestamp){
                // unlockable amounts
                unlockable += lock.amount;
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
        uint256 lockedAmount = lock.amount;
        // liquidate threshold: 100%
        require(debt >= lockedAmount, "uEVMOS Kill: Still safe.");
        
        IVault(lock.vault).repayInBase{value: lockedAmount}(lock.account, 1);
        lock.received = true;
        /// @dev event Kill?
    }


    receive() external payable {}

    fallback() external payable {}

}