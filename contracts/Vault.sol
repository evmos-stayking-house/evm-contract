// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import 'hardhat/console.sol';
import './interface/IVault.sol';
import './interface/IInterestModel.sol';
import './interface/ISwapHelper.sol';
import './interface/IStayking.sol';
import './lib/ERC20Upgradeable.sol';
import './lib/OwnableUpgradeable.sol';
import './lib/interface/IERC20.sol';
import './lib/utils/SafeToken.sol';

/************************************************************
 * @dev Glossary
 * amount vs share
 * amount => unit of baseToken
 * share => unit of ibToken
 *************************************************************/
contract Vault is IVault, ERC20Upgradeable, OwnableUpgradeable {

    address private constant BASE_TOKEN = address(0);
    uint256 private constant DENOM = 1E18;

    event Deposit(address user, uint256 amount, uint256 share);
    event Withdraw(address user, uint256 amount, uint256 share);
    event Loan(address user, uint256 debtAmount);
    event Repay(address user, uint256 debtAmount);
    event PayInterest(uint256 paidInterest, uint256 remained, uint256 insufficient);
    event TransferDebtOwnership(address from, address to, uint256 amount);
    event UtilizationRate(uint256 rateBps);
    event RepayPendingDebt(address user, uint256 amount, uint256 pendingDebt, uint256 pendingDebtInBase, uint256 remained);

    ISwapHelper public swapHelper;

    address public override token;
    address public override stayking;
    address public override interestModel;

    /** @dev
    totalAmount == Token.balanceOf(this) + totalStakedDebtAmount + totalPendingDebtAmount
    totalShare == totalSupply()
    */

    // Debt Amounts
    mapping(address => uint256) public override debtAmountOf;
    uint256 public override totalStakedDebtAmount;

    // Pending Debts
    mapping(address => uint256) public pendingDebtShareOf;
    uint256 public override totalPendingDebtShare;
    uint256 public override totalPendingDebtAmount;

    uint256 public override minReservedBps;
    uint256 public override lastAccruedAt;
    uint256 public override accInterest;

    // information of last paid interest amount & time
    // these 5 values change every day when interest is paid.
    // APR = 365 * lastReward / lastTotalAmount;
    struct LastPaid {
        uint256 totalDebtAmount;
        uint256 totalAmount;
        uint256 reward;
        uint128 timestamp;
        uint128 interval;
    }
    LastPaid public lastPaid;

    /*************
     * Modifiers *
     **************/

    modifier onlyStayking() {
        require(msg.sender == stayking, 'Vault: Not Stayking contract.');
        _;
    }

    modifier accrueBefore() {
        _accrue();
        _;
    }

    /****************
     * Initializer *
     *****************/

    function __Vault_init(
        string calldata _name,
        string calldata _symbol,
        address _swapHelper,
        address _stayking,
        address _token,
        address _interestModel,
        uint256 _minReservedBps
    ) external initializer {
        // require(_stayking != address(0), 'Vault: Stayking address is zero');
        require(_token != address(0), 'Vault: Base Token is zero address');

        __ERC20_init(_name, _symbol);
        __Ownable_init();

        token = _token;
        stayking = _stayking;
        lastAccruedAt = block.timestamp;
        updateMinReservedBps(_minReservedBps);
        updateInterestModel(_interestModel);
        updateSwapHelper(_swapHelper);

        lastPaid = LastPaid({
            totalDebtAmount: 0,
            totalAmount: 0,
            reward: 0,
            timestamp: uint128(block.timestamp),
            interval: uint128(0)
        });
    }

    function getAccruedRateBps()
        public
        view
        returns (uint256 baseBps, uint256 bonusBps)
    {
        uint256 amount = totalAmount();
        
        if (amount == 0) {
            return (0, 0);
        }

        baseBps =
            (1E4 * getInterestRate() * totalDebtAmount() * 365 days) /
            amount /
            1E18;

        bonusBps =
            IStayking(stayking).totalAmount() == 0 ? 0 : (getBaseIn(totalStakedDebtAmount) *
                IStayking(stayking).vaultRewardBps()) /
            IStayking(stayking).totalAmount();
    }

    // @dev (token in vault) + (debt)
    function totalDebtAmount() public view override returns (uint256) {
        return totalStakedDebtAmount + totalPendingDebtAmount;
    }

    function totalAmount() public view override returns (uint256) {
        return IERC20(token).balanceOf(address(this)) + totalDebtAmount();
    }

    function updateMinReservedBps(uint256 _minReservedBps)
        public
        override
        onlyOwner
    {
        minReservedBps = _minReservedBps;
    }

    function updateInterestModel(address _interestModel)
        public
        override
        onlyOwner
    {
        interestModel = _interestModel;
    }

    function updateSwapHelper(address _swapHelper) public override onlyOwner {
        swapHelper = ISwapHelper(_swapHelper);
    }

    function amountToShare(uint256 amount) public view returns (uint256) {
        uint256 _totalAmount = totalAmount();
        return
            (_totalAmount == 0)
                ? amount
                : (totalSupply() * amount) / _totalAmount;
    }

    function shareToAmount(uint256 share) public view returns (uint256) {
        uint256 totalShare = totalSupply();
        return (totalShare == 0) ? share : (totalAmount() * share) / totalShare;
    }

    function debtAmountInBase(address user)
        public
        view
        override
        returns (uint256)
    {
        return getBaseIn(debtAmountOf[user]);
    }

    function pendingDebtAmountToShare(uint256 amount)
        public
        view
        override
        returns (uint256)
    {
        return
            (totalPendingDebtAmount == 0)
                ? amount
                : (totalPendingDebtShare * amount) / totalPendingDebtAmount;
    }

    function pendingDebtShareToAmount(uint256 share)
        public
        view
        override
        returns (uint256)
    {
        return
            (totalPendingDebtShare == 0)
                ? share
                : (totalPendingDebtAmount * share) / totalPendingDebtShare;
    }

    /// @notice Amount of interest paid per second
    /// @dev denominator = 1E18
    function getInterestRate()
        public
        view
        override
        returns (uint256 interestRate)
    {
        interestRate = IInterestModel(interestModel).calcInterestRate(
            totalDebtAmount(),
            IERC20(token).balanceOf(address(this))
        );
    }

    function utilizationRateBps() public view override returns (uint256) {
        uint256 amount = totalAmount();
        if (amount == 0) return 0;

        return (1E4 * totalDebtAmount()) / amount;
    }

    /**
        @dev
        Before each time the position is changed,
        the interest on "Stayking debt" (not on "pending debt")
        during (lastAccruedAt ~ present) is calculated and added.
     */
    function _accrue() private {
        if (block.timestamp <= lastAccruedAt) return;
        uint256 timePast = block.timestamp - lastAccruedAt;

        uint256 stakedInterest = (getInterestRate() *
            totalStakedDebtAmount *
            timePast) / DENOM;

        accInterest += stakedInterest;

        uint256 pendingInterest = (getInterestRate() *
            totalPendingDebtAmount *
            timePast) / DENOM;
        totalPendingDebtAmount += pendingInterest;

        lastAccruedAt = block.timestamp;
    }

    /// @dev for test -> should be REMOVED
    function accrue() public {
        _accrue();
    }

    /******************
     * Swap Functions *
     *******************/
    /**
     @dev
     baseAmount: amount of EVMOS
     tokenAmount: amount of vault token (e.g. ATOM, USDC, ...etc)
     */

    /// @dev vault token -> baseToken(EVMOS) (known baseAmount)
    function _swapToBase(uint256 baseAmount)
        private
        returns (uint256 tokenAmount)
    {
        // 1. calculate amountIn
        tokenAmount = getTokenIn(baseAmount);
        // 2. approve to swapHelper
        SafeToken.safeApprove(token, address(swapHelper), tokenAmount);
        // 3. swap
        swapHelper.exchange(token, BASE_TOKEN, tokenAmount, baseAmount);
    }

    /// @dev baseToken(EVMOS) -> vault token (known baseAmount)
    function _swapFromBase(uint256 baseAmount, uint256 minDy)
        private
        returns (uint256 tokenAmount)
    {
        return
            swapHelper.exchange{value: baseAmount}(
                BASE_TOKEN,
                token,
                baseAmount,
                minDy
            );
    }

    /**
     @notice swapHelper calc functions
     function naming: get[ target of token ][ direction ]
      * target:     Base(EVMOS)  / Token
      * direction:  In(=getDx) / Out(=getDy)

      e.g. function getBaseIn()
      -> this func calculates how much EVMOS is needed to swap EVMOS to Token.
     */

    /// @dev calc (?)EVMOS = $ token
    function getBaseIn(uint256 tokenOut)
        public
        view
        override
        returns (uint256 baseIn)
    {
        return swapHelper.getDx(BASE_TOKEN, token, tokenOut);
    }

    /// @dev calc $ token = (?)EVMOS
    function getBaseOut(uint256 baseIn)
        public
        view
        override
        returns (uint256 tokenOut)
    {
        return swapHelper.getDy(token, BASE_TOKEN, baseIn);
    }

    /// @dev calc (?)token = $ EVMOS
    function getTokenIn(uint256 baseOut)
        public
        view
        override
        returns (uint256 tokenIn)
    {
        return swapHelper.getDx(token, BASE_TOKEN, baseOut);
    }

    /// @dev calc $ EVMOS = (?)token
    function getTokenOut(uint256 tokenIn)
        public
        view
        override
        returns (uint256 baseOut)
    {
        return swapHelper.getDy(BASE_TOKEN, token, tokenIn);
    }

    /************************************
     * interface IVault Implementations
     ************************************/

    /// @notice user approve should be preceded
    function deposit(uint256 amount)
        public
        override
        accrueBefore
        returns (uint256 share)
    {
        share = amountToShare(amount);
        SafeToken.safeTransferFrom(token, msg.sender, address(this), amount);
        _mint(msg.sender, share);

        emit Deposit(msg.sender, amount, share);
    }

    function withdraw(uint256 share)
        public
        override
        accrueBefore
        returns (uint256 amount)
    {
        amount = shareToAmount(share);
        // TODO minReserved?
        _burn(msg.sender, share);
        SafeToken.safeTransfer(token, msg.sender, amount);

        emit Withdraw(msg.sender, amount, share);
    }

    /// @notice loan is only for Stayking contract.
    function loan(address user, uint256 debtInBase)
        public
        override
        onlyStayking
        accrueBefore
        returns (uint256 debt)
    {
        require(user != address(0), 'loan: zero address cannot loan.');

        ///@dev swap token -> (amountInBase)EVMOS
        debt = _swapToBase(debtInBase);
        debtAmountOf[user] += debt;
        totalStakedDebtAmount += debt;
        require(
            (totalStakedDebtAmount + totalPendingDebtAmount) * 1E4 <=
                totalAmount() * (1E4 - minReservedBps),
            "Loan: Cant' loan debt anymore."
        );
        SafeToken.safeTransferEVMOS(msg.sender, debtInBase);
        emit Loan(user, debt);
    }

    // @TODO Should approve MAX_UINT?
    /// @dev Repay user's debt.
    /// Stayking should approve token first.
    function _repay(address user, uint256 amount) private accrueBefore {
        require(
            debtAmountOf[user] >= amount,
            'repay: too much amount to repay.'
        );
        unchecked {
            debtAmountOf[user] -= amount;
        }
        totalStakedDebtAmount -= amount;
        emit Repay(user, amount);
    }

    function repayInToken(address user, uint256 amount)
        public
        override
        onlyStayking
    {
        SafeToken.safeTransferFrom(token, user, address(this), amount);
        _repay(user, amount);
    }

    /// @dev partial close 기능인데 일단 현재는 add equity/debt 만 가능한 구조이므로 deprecated 함
    /// @dev repay debt for Base token(EVMOS).
    /// @param user debt owner
    /// @param minRepaid  minimum repaid debtToken amonut
    function repayInBase(address user, uint256 minRepaid)
        public
        payable
        override
        onlyStayking
        returns (uint256 repaid)
    {
        repaid = _swapFromBase(msg.value, minRepaid);
        _repay(user, repaid);
    }

    function takeDebtOwnership(address from, uint256 amount)
        public
        override
        onlyStayking
    {
        require(
            debtAmountOf[from] >= amount,
            'takeDebtOwnership: too much amount to take.'
        );
        unchecked {
            debtAmountOf[from] -= amount;
        }
        debtAmountOf[msg.sender] += amount;
        emit TransferDebtOwnership(from, msg.sender, amount);
    }

    /// @dev calculate interest (1 day) in base (EVMOS)
    function getInterestInBase() public view override returns (uint256) {
        return accInterest > 0 ? getBaseIn(accInterest) : 0;
    }

    // msg.value = interest + reward(bonus)
    function payInterest(uint256 minPaidInterest)
        public
        payable
        override
        onlyStayking
        accrueBefore
    {
        require(
            block.timestamp > uint256(lastPaid.timestamp),
            'payInterest: already paid.'
        );
        uint256 paidInterest = _swapFromBase(msg.value, minPaidInterest);

        lastPaid.totalDebtAmount = totalDebtAmount();
        lastPaid.totalAmount = totalAmount();
        lastPaid.interval = uint128(block.timestamp) - lastPaid.timestamp;
        lastPaid.timestamp = uint128(block.timestamp);
        lastPaid.reward = paidInterest;

        emit PayInterest(
            paidInterest, 
            paidInterest > accInterest ? paidInterest - accInterest : 0, 
            accInterest > paidInterest ? accInterest - paidInterest : 0
        );
        // 부족하든 부족하지 않든 이자를 지급하고 축적된 Vault 의 accInterest 는 0 으로 초기화 하여 Epoch 마다 Reset 함
        accInterest = 0;
    }

    /// @dev pending repay debt because of EVMOS Unstaking's 14 days lock.
    /// Stayking should approve token first.
    function pendRepay(address user, uint256 amount)
        public
        override
        onlyStayking
        returns (uint256 pendingDebtShare)
    {
        require(
            amount <= debtAmountOf[user],
            'pendRepay: too much amount to repay.'
        );
        /// @dev subtract from debtAmountOf[user]
        unchecked {
            debtAmountOf[user] -= amount;
        }
        totalStakedDebtAmount -= amount;

        /// @dev The pendingDebtAmount increases over time.
        /// This is because lending interest is charged during the 14 days of unbonding.
        pendingDebtShare = pendingDebtAmountToShare(amount);
        pendingDebtShareOf[user] += pendingDebtShare;

        totalPendingDebtShare += pendingDebtShare;
        totalPendingDebtAmount += amount;
    }

    function getPendingDebt(address user)
        public
        view
        override
        returns (uint256)
    {
        return pendingDebtShareToAmount(pendingDebtShareOf[user]);
    }

    function getPendingDebtInBase(address user)
        public
        view
        override
        returns (uint256)
    {
        return getBaseIn(getPendingDebt(user));
    }

    /// @dev stayking should send with msg.value(=repayingDebtInBase)
    function repayPendingDebt(address user)
        public
        payable
        override
        returns (uint256 remained)
    {
        uint256 pendingDebt = getPendingDebt(user);
        uint256 pendingDebtInBase = getBaseIn(pendingDebt);

        if (msg.value > pendingDebtInBase) {
            _swapFromBase(pendingDebtInBase, pendingDebt);
            // return remained EVMOS
            remained = msg.value - pendingDebtInBase;
            SafeToken.safeTransferEVMOS(msg.sender, remained);
        } else {
            /**
             * @dev unbonding 이후 빚보다 EVMOS 수량이 적을 때 share 에서 차감하는 방식이었는데
             *      프로토콜에 손해가 있더라도 무조건 유저의 pending debt share 를 0 으로 초기화 하는 게 더 나음
             *      청산 임계치 killFactor 를 조절하는 것이 더 나음 ( 현재 75 % )
             **/
            // uint256 repaidDebtAmount = _swapFromBase(msg.value, 1);
            // uint256 repaidDebtShare = pendingDebtAmountToShare(repaidDebtAmount);
            // pendingDebtShareOf[user] -= repaidDebtShare;
            remained = 0;
        }
        pendingDebtShareOf[user] = 0;

        emit RepayPendingDebt(user, msg.value, pendingDebt, pendingDebtInBase, remained);
    }

    /// @dev Fallback function to accept EVMOS.
    receive() external payable {}

    fallback() external payable {}
}
