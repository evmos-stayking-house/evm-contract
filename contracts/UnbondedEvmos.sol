// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import 'hardhat/console.sol';
import './interface/IUnbondedEvmos.sol';
import './interface/IVault.sol';
import './lib/OwnableUpgradeable.sol';
import './lib/ERC20Upgradeable.sol';
import './lib/utils/SafeToken.sol';

contract UnbondedEvmos is IUnbondedEvmos, OwnableUpgradeable, ERC20Upgradeable {

    event Lock(address account, address vault, uint256 lockedIndex);
    event Unlock(address account, uint256 amount, uint256 returned);
    event Supply(uint256 amount);
    event Withdraw(address account, uint256 amount);
    event UpdateMinterStatus(address account, bool status);
    event UpdateConfigs(uint256 unbondingInterval);

    mapping(address => bool) public override isMinter;

    uint256 public override lastUnbondedAt;
    // it depends on the parameter values of the governance in the protocol, testnet : 7 days, mainnet : 14days
    uint256 public override unbondingInterval; 

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

    /** 
     * @dev
     *  lockedIds: lock 된 EVMOS 자산 정보 locks 의 index 값 
     *  nextUnlocked : 다음 search 할 index 값 
     */
    struct LockedQueue {
        uint256 nextUnlocked;
        uint256[] lockedIds;
    }
    mapping(address => LockedQueue) public lockedOf;
    mapping(address => uint256) _balances;

    /// @notice should set minter (maybe Stayking) after deployed
    function __UnbondedEvmos_init(uint256 unbondingInterval_)
        external
        initializer
    {
        __Ownable_init();
        __ERC20_init(
            'Unstaked EVMOS', // name
            'uEVMOS' //symbol
        );
        updateConfigs(unbondingInterval_);
    }

    /**************
        Modifier
     *************/
    modifier onlyMinter() {
        require(isMinter[msg.sender], 'uEVMOS: Not minter.');
        _;
    }

    function updateMinterStatus(address account, bool status)
        public
        override
        onlyOwner
    {
        isMinter[account] = status;
        emit UpdateMinterStatus(account, status);
    }

    function updateConfigs(uint256 _unbondingInterval) public onlyOwner {
        unbondingInterval = _unbondingInterval;
        emit UpdateConfigs(_unbondingInterval);
    }

    /******************
       Public Functions
    *******************/
    function transfer(address to, uint256 amount)
        public
        override
        onlyMinter
        returns (bool)
    {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override onlyMinter returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    /**
     * @dev mint & lock uEVMOS from Stayking contarct removePosition, kill function execution.
     **/
    function mintLockedToken(
        address to,
        address vault,
        uint256 amount,
        uint256 debtShare
    ) public override onlyMinter {
        require(amount > 0, 'mintLockedToken: amount 0 is not allowed.');

        LockedQueue storage lockedQueue = lockedOf[to];

        /// @dev consume all of unlock queue
        // _unlock(to, lockedQueue);

        uint256 unlockedAt = _getUnlockedAt();

        Locked memory locked = Locked({
            account: to,
            vault: vault,
            amount: amount,
            debtShare: debtShare,
            unlockedAt: unlockedAt,
            received: false
        });

        locks.push(locked);

        uint256 newLockedId = locks.length - 1;
        lockedQueue.lockedIds.push(newLockedId);

        _mint(to, amount);

        emit Lock(to, vault, newLockedId);
    }

    function unlock() public override {
        LockedQueue storage lockedQueue = lockedOf[msg.sender];
        uint256[] memory lockedIds = lockedQueue.lockedIds;
        uint256 nextUnlocked = lockedQueue.nextUnlocked;

        require(lockedIds.length > 0, "user's locked asset is empty");

        uint256 unlockable;
        uint256 returnable;
        uint256 nextIdx = _getNextIdxOfLockedQueue(lockedIds, nextUnlocked);

        for (; nextIdx < lockedIds.length; nextIdx++) {
            Locked storage lock = locks[lockedIds[nextIdx]];

            if (lock.unlockedAt <= block.timestamp && lock.received == false) {
                /// @dev unlockable
                unlockable += lock.amount;
                /// @dev kor) (개선 필요) aggregate하여 repay 횟수 줄이기
                uint256 returned = _repayPendingDebt(lock);
                returnable += returned;
            }
        }

        if (unlockable > 0) {
            lockedQueue.nextUnlocked = nextIdx - 1;
            
            _burn(msg.sender, unlockable);

            // 3. return EVMOS is returnable exists
            if (returnable > 0) {
                SafeToken.safeTransferEVMOS(msg.sender, returnable);
            }
            emit Unlock(msg.sender, unlockable, returnable);
        }
    }

    function getLockedList(address account)
        public
        view
        returns (Locked[] memory accountLocks)
    {
        LockedQueue memory lockedQueue = lockedOf[account];
        uint256[] memory lockedIds = lockedQueue.lockedIds;

        if (lockedIds.length == 0)
            return new Locked[](0);

        uint256 nextUnlocked = lockedQueue.nextUnlocked;
        uint256 nextIdx = _getNextIdxOfLockedQueue(lockedIds, nextUnlocked);

        accountLocks = new Locked[](lockedIds.length - nextIdx);

        uint256 accountLocksIdx = 0;
        for (uint256 i = nextIdx; i < lockedIds.length; i++) {
            Locked memory locked = locks[lockedIds[i]];
            accountLocks[accountLocksIdx++] = locked;
        }

        return accountLocks;
    }

    /// @dev calc user's unlockable uEVMOS(includes debt) & debt
    function getUnlockable(address account)
        public
        view
        override
        returns (uint256 unlockable, uint256 debt)
    {
        uint256 nextUnlocked = lockedOf[account].nextUnlocked;
        uint256[] memory lockedIds = lockedOf[account].lockedIds;

        if (lockedIds.length == 0)
            return (0, 0);
        
        uint256 nextIdx = _getNextIdxOfLockedQueue(lockedIds, nextUnlocked);
        
        for (uint256 i = nextIdx; i < lockedIds.length; i++) {
            Locked memory lock = locks[lockedIds[i]];
            if (lock.unlockedAt <= block.timestamp && lock.received == false) {
                // unlockable amounts
                unlockable += lock.amount;
                debt += IVault(lock.vault).getPendingDebtInBase(account);
            }
        }
    }


    function supplyUnbondedToken() public payable override {
        lastUnbondedAt = block.timestamp;
        emit Supply(msg.value);
    }

    function getLockedOf(address account) public view returns (LockedQueue memory lockedQueue) {
        lockedQueue = lockedOf[account];
    }

    /// @notice TODO
    /// 유저가 일부만 unstake 요청하는 경우, 빚을 다 못 갚는 경우가 당연히 발생한다. 일단 부채비율이 100% 넘기는 경우 우리가 unlock 시키는 것만 구현.
    function isKillable(uint256 lockedId) external view override returns (bool) {
        Locked memory lock = locks[lockedId];
        if (lock.unlockedAt > block.timestamp || lock.received == true) return false;
        uint256 debt = IVault(lock.vault).getPendingDebtInBase(lock.account);
        return debt >= lock.amount;
    }

    function kill(uint256 lockedId) public override {
        Locked storage lock = locks[lockedId];
        require(
            lock.unlockedAt <= block.timestamp || lock.received == true,
            'uEVMOS Kill: Cannot Unlock.'
        );
        uint256 debt = IVault(lock.vault).getPendingDebtInBase(lock.account);
        uint256 lockedAmount = lock.amount;
        // liquidate threshold: 100%
        require(debt >= lockedAmount, 'uEVMOS Kill: Still safe.');

        IVault(lock.vault).repayInBase{value: lockedAmount}(lock.account, 1);
        lock.received = true;
        /// @dev event Kill?
    }

    /******************
       Private Functions
    *******************/

    function _repayPendingDebt(Locked storage lock) private returns (uint256 returnable) {
        IVault vault = IVault(lock.vault);
        address account = lock.account;
        uint256 amount = lock.amount;

        // Vault 의 repayPendingDebt 함수를 호출할 때 전체 unlockable 해진 유저의 EVMOS 를 보내 빚을 갚고 남은 EVMOS를 다시 uEVMOS 컨트랙트로 돌려줌
        returnable = IVault(vault).repayPendingDebt{value: amount}(account);
        lock.received = true;
    }

    function _getUnlockedAt() private view returns (uint256) {
        return (lastUnbondedAt > block.timestamp ? lastUnbondedAt : block.timestamp) + unbondingInterval;
    }

    function _getNextIdxOfLockedQueue(uint256[] memory lockedIds, uint256 nextUnlocked) private pure returns (uint256) {
        for (uint256 idx = lockedIds.length; idx > 0; idx--) {
            if(lockedIds[idx - 1] < nextUnlocked) {
                return idx;
            }
        }
        return 0;
    }

    /******************
       Ext functions
    *******************/

    function sweep() public onlyOwner {
        SafeToken.safeTransferEVMOS(msg.sender, address(this).balance);
    }

    receive() external payable {}

    fallback() external payable {}
}