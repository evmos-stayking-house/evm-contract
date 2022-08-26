// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

import "../interface/IUnbondedEvmos.sol";
import "../interface/IVault.sol";
import "../lib/OwnableUpgradeable.sol";
import "../lib/utils/SafeToken.sol";
import "hardhat/console.sol";

contract UnbondedEvmos is IUnbondedEvmos, OwnableUpgradeable { 

    event Lock(address account, address vault, uint256 lockedIndex);
    event Unlock(address account, uint256 amount, uint256 returned);
    event Supply(uint256 amount);
    event Withdraw(address account, uint256 amount);
    event UpdateMinterStatus(address account, bool status);
    event UpdateConfigs(uint256 unbondingInterval);

    mapping(address => bool) public override isMinter;

    string public constant name = "Unstaked EVMOS";
    string public constant symbol = "uEVMOS";
    uint8 public constant decimals = 18;

    uint256 public override lastUnbondedAt;
    uint256 public override unbondingInterval;   // maybe 14 + 2 days

    uint256 public totalAmount;
    uint256 public totalShare;

    /// @notice kor) 논의 필요
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
     lastUnlocked: last unlocked index of "lockedIds"
     */
    struct LockedQueue {
        uint256 lastUnlocked;
        uint256[] lockedIds;
    }
    mapping(address => LockedQueue) public lockedOf;
    mapping(address => uint256) _balances;
    uint256 public override totalSupply;

    /// @notice should set minter (maybe Stayking) after deployed
    function __UnbondedEvmos_init(
        uint256 unbondingInterval_
    ) external initializer {
        __Ownable_init();
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

    /// @return restUnlocked EVMOS amount that user can receive
    function _repayPendingDebt(
        Locked storage lock,
        uint256 minRepaid
    ) private returns (uint256) {
        IVault vault = IVault(lock.vault);
        address account = lock.account;
        uint256 amount = lock.amount;

        uint256 pendingDebtInBase = vault.pendingDebtShareToAmount(lock.debtShare);
        lock.received = true;
        if(amount >= pendingDebtInBase){
            IVault(vault).repayInBase{value: pendingDebtInBase}(account, minRepaid);
            return amount - pendingDebtInBase;
        }
        else {
            vault.repayInBase{value: amount}(account, minRepaid);
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
        uint256 lastUnlocked = lockedQueue.lastUnlocked; 
        uint256 queueLength = lockedQueue.lockedIds.length;

        if(lastUnlocked == queueLength)   // no unlockable amounts
            return;

        uint256 unlockable;
        uint256 returnable;
        uint256 i = lastUnlocked + 1;
        
        // assert under 7 loop.
        for (i; i < queueLength; i++) {
            uint256 lockedId = lockedQueue.lockedIds[i];
            Locked storage lock = locks[lockedId];
            
            if(lock.unlockedAt <= block.timestamp){  /// @dev unlockable
                unlockable += lock.amount;

                /// @dev kor) (개선 필요) aggregate하여 repay 횟수 줄이기
                returnable += _repayPendingDebt(
                    lock,
                    minRepaid
                );
            }
            else 
                break;
        }

        // if unlockable > 0, i > lastUnlocked
        if(unlockable > 0){

            lockedQueue.lastUnlocked = i;           // 1. reset queue front
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
        /**
            @TODO
            maybe use delegate/undelegate tx ORACLE?
         */
        lastUnbondedAt = block.timestamp;
    }

    /// @dev calc user's unlockable uEVMOS(includes debt) & debt
    function getUnlockable(
        address account
    ) public override view returns(uint256 unlockable, uint256 debt) {
        uint256 lastUnlocked = lockedOf[account].lastUnlocked; 
        uint256 queueLength = lockedOf[account].lockedIds.length; 
        uint256[] memory lockedIds = lockedOf[account].lockedIds;

        if(lastUnlocked == queueLength)   // no unlockable amounts
            return (0, 0);
        
        // TODO assert under 7 loop?
        // kor) 가스비 너무 많이 들게 되면 트랜잭션 실패할듯..
        for (uint256 i = lastUnlocked + 1; i < queueLength; i++) {
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