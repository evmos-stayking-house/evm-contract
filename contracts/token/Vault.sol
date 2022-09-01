// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "../interface/IVault.sol";
import "../interface/IInterestModel.sol";
import "../interface/ISwapHelper.sol";
import "../lib/ERC20Upgradeable.sol";
import "../lib/OwnableUpgradeable.sol";
import "../lib/interface/IERC20.sol";
import "../lib/utils/SafeToken.sol";


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
    // kor) Loan과 Repay는 Stayking의 ChangePosition 등의 이벤트와 중복되는데, 없애도 좋을지?
    event Loan(address user, uint256 debtAmount);
    event Repay(address user, uint256 debtAmount);
    event PayInterest(uint256 paidInterest, uint256 leftInterest);
    event TransferDebtOwnership(address from, address to, uint256 amount);
    event UtilizationRate(uint256 rateBps);

    ISwapHelper public swapHelper;

    address public override token;
    address public override stayking;
    address public override interestModel;

    /**
        @dev
        totalAmount == Token.balanceOf(this) + totalDebtAmount
        totalShare == totalSupply()
     */

    // Debt Amounts
    mapping(address => uint256) public override debtAmountOf;
    uint256 public override totalDebtAmount;

    // Pending Debts
    mapping(address => uint256) public pendingDebtShareOf;
    uint256 public totalPendingDebtShare;
    uint256 public totalPendingDebtAmount;

    uint256 public minReservedBps;
    uint256 public yesterdayUtilRate;
    uint256 public lastSavedUtilizationRateTime;

    uint256 public lastAccruedAt;
    uint256 public override accInterest;


    /*************
     * Modifiers *
    **************/

    modifier onlyStayking(){
        require(msg.sender == stayking, "Vault: Not Stayking contract.");
        _;
    }

    modifier saveUtilRate() {
        _accrue();
        _;
        saveUtilizationRateBps();
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
        require(_stayking != address(0), "Vault: Stayking address is zero");
        require(_token != address(0), "Vault: Base Token is zero address");
        
        __ERC20_init(_name, _symbol);
        __Ownable_init();

        token = _token;
        stayking = _stayking;
        lastAccruedAt = block.timestamp;
        updateMinReservedBps(_minReservedBps);
        updateInterestModel(_interestModel);
        updateSwapHelper(_swapHelper);

        // @TODO changed
        lastSavedUtilizationRateTime = block.timestamp - 
            ((block.timestamp - 1639098000) % 1 days);
    }

    // @dev (token in vault) + (debt)
    function totalAmount() public override view returns(uint256){
        return IERC20(token).balanceOf(address(this)) + totalDebtAmount + totalPendingDebtAmount;
    }

    function updateMinReservedBps(uint256 _minReservedBps) public override onlyOwner {
        minReservedBps = _minReservedBps;
    }

    function updateInterestModel(address _interestModel) public override onlyOwner {
        interestModel = _interestModel;
    }
    
    function updateSwapHelper(address _swapHelper) public override onlyOwner {
        swapHelper = ISwapHelper(_swapHelper);
    }

    function amountToShare(
        uint256 amount
    ) public view returns(uint256) {
        uint256 _totalAmount = totalAmount();
        return (_totalAmount == 0) ? amount :
            (totalSupply() * amount) / _totalAmount;
    }

    function shareToAmount(
        uint256 share
    ) public view returns(uint256) {
        uint256 totalShare = totalSupply();
        return (totalShare == 0) ? share :
            (totalAmount() * share) / totalShare;
    }

    function debtAmountInBase(
        address user
    ) public override view returns(uint256){
        return getBaseIn(debtAmountOf[user]);
    }

    function pendingDebtAmountToShare(
        uint256 amount
    ) public override view returns(uint256) {
        return (totalPendingDebtAmount == 0) ? amount : 
            (totalPendingDebtShare * amount) / totalPendingDebtAmount;
    }

    function pendingDebtShareToAmount(
        uint256 share
    ) public override view returns(uint256) {
        return (totalPendingDebtShare == 0) ? share : 
            (totalPendingDebtAmount * share) / totalPendingDebtShare;
    }

    /// @dev denominator = 1E18 
    function getInterestRate() public override view returns(uint256 interestRate){
        interestRate = IInterestModel(interestModel)
            .calcInterestRate(
                totalDebtAmount + totalPendingDebtAmount,
                IERC20(token).balanceOf(address(this))
            );
    }

    function utilizationRateBps() public override view returns(uint256){
        return 1E4 * (totalDebtAmount + totalPendingDebtAmount) / totalAmount();
    }

    function saveUtilizationRateBps() public override {
        if (block.timestamp >= lastSavedUtilizationRateTime + 1 days) {
            yesterdayUtilRate = utilizationRateBps();
            lastSavedUtilizationRateTime += 1 days;
            // accInterest += getInterestRate() * 86400;
            emit UtilizationRate(yesterdayUtilRate);
        }
    }

    /**
        @dev 
        Before each time the position is changed, 
        the interest on "Stayking debt" (not on "pending debt")
        during (lastAccruedAt ~ present) is calculated and added.
     */
    function _accrue() private {
        if (block.timestamp <= lastAccruedAt) 
            return;
        uint256 timePast = block.timestamp - lastAccruedAt;

        /// @dev get interest rate by utilization rate
        uint256 interest = (getInterestRate() * (totalDebtAmount + accInterest) * timePast) 
            / DENOM;

        accInterest += interest;
        lastAccruedAt = block.timestamp;
    }

    /// @dev for test -> should be REMOVED
    function accrue () public {
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
    function _swapToBase(uint256 baseAmount) private returns(uint256 tokenAmount) {
        // 1. calculate amountIn
        tokenAmount = getTokenIn(baseAmount);
        // 2. approve to swapHelper
        SafeToken.safeApprove(token, address(swapHelper), tokenAmount);
        // 3. swap
        swapHelper.exchange(token, BASE_TOKEN, tokenAmount, baseAmount);
    }

    /// @dev baseToken(EVMOS) -> vault token (known baseAmount)
    function _swapFromBase(uint256 baseAmount, uint256 minDy) private returns(uint256 tokenAmount) {
        return swapHelper.exchange{value: baseAmount}(BASE_TOKEN, token, baseAmount, minDy);
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
    function getBaseIn(
        uint256 tokenOut
    ) public override view returns(uint256 baseIn) {
        return swapHelper.getDx(BASE_TOKEN, token, tokenOut);
    }

    /// @dev calc $ EVMOS = (?)token
    function getBaseOut(
        uint256 tokenIn
    ) public override view returns(uint256 baseOut) {
        return swapHelper.getDy(BASE_TOKEN, token, tokenIn);
    }

    /// @dev calc (?)token = $ EVMOS
    function getTokenIn(
        uint256 baseOut
    ) public override view returns(uint256 tokenIn) {
        return swapHelper.getDx(token, BASE_TOKEN, baseOut);
    }
    
    /// @dev calc $ token = (?)EVMOS
    function getTokenOut(
        uint256 baseIn
    ) public override view returns(uint256 tokenOut) {
        return swapHelper.getDy(token, BASE_TOKEN, baseIn);
    }
    
    /************************************
     * interface IVault Implementations
     ************************************/

    /// @notice user approve should be preceded
    function deposit(
        uint256 amount
    ) public override saveUtilRate returns(uint256 share){
        share = amountToShare(amount);
        SafeToken.safeTransferFrom(token, msg.sender, address(this), amount);
        _mint(msg.sender, share);

        emit Deposit(msg.sender, amount, share);
    }

    function withdraw(
        uint256 share
    ) public override saveUtilRate returns(uint256 amount){
        amount = shareToAmount(share);
        // TODO minReserved?
        _burn(msg.sender, share);
        SafeToken.safeTransfer(token, msg.sender, amount);

        emit Withdraw(msg.sender, amount, share);
    }

    /// @notice loan is only for Stayking contract.
    function loan(
        address user,
        uint256 debtInBase
    ) public override onlyStayking saveUtilRate returns (uint256 debt) {
        require(user != address(0), "loan: zero address cannot loan.");

        ///@dev swap token -> (amountInBase)EVMOS
        debt = _swapToBase(debtInBase);
        debtAmountOf[user] += debt;
        totalDebtAmount += debt;

        require(
            (totalDebtAmount + totalPendingDebtAmount) * 1E4 <= totalAmount() * (1E4 - minReservedBps),
            "Loan: Cant' loan debt anymore."
        );

        SafeToken.safeTransferEVMOS(msg.sender, debtInBase);
        emit Loan(user, debt);
    }

    // @TODO Should approve MAX_UINT?
    /// @dev Repay user's debt.
    /// Stayking should approve token first.
    function _repay(
        address user,
        uint256 amount
    ) private saveUtilRate {
        require(debtAmountOf[user] >= amount, "repay: too much amount to repay.");
        unchecked {
            debtAmountOf[user] -= amount;
        }
        totalDebtAmount -= amount;
        emit Repay(user, amount);
    }

    function repayInToken(
        address user,
        uint256 amount
    ) public override onlyStayking {
        SafeToken.safeTransferFrom(token, user, address(this), amount);
        _repay(user, amount);
    }

    /// @dev repay debt for Base token(EVMOS).
    /// @param user debt owner
    /// @param minRepaid  minimum repaid debtToken amonut
    function repayInBase(
        address user,
        uint256 minRepaid
    ) public payable override onlyStayking returns(uint256 repaid) {
        repaid = _swapFromBase(msg.value, minRepaid);
        _repay(user, repaid);
    }

    function takeDebtOwnership(
        address from,
        uint256 amount
    ) public override onlyStayking {
        require(debtAmountOf[from] >= amount, "takeDebtOwnership: too much amount to take.");
        unchecked {
            debtAmountOf[from] -= amount;
        }
        debtAmountOf[msg.sender] += amount;
        emit TransferDebtOwnership(from, msg.sender, amount);
    }

    /// @dev calculate interest (1 day) in base (EVMOS)
    function getInterestInBase() public override view returns(uint256) {
        return accInterest > 0 ? getBaseIn(accInterest) : 0;
    }

    function payInterest(
        uint256 minPaidInterest
    ) public payable override onlyStayking saveUtilRate {
        uint256 interestInBase = getInterestInBase();
        uint256 paidInterest;
        
        if(msg.value > interestInBase){
            paidInterest = _swapFromBase(interestInBase, accInterest);
            // return remained EVMOS
            SafeToken.safeTransferEVMOS(msg.sender, msg.value - interestInBase);
            accInterest -= paidInterest;
        }
        else {
            paidInterest = _swapFromBase(msg.value, minPaidInterest);
            accInterest -= paidInterest;
        }

        emit PayInterest(paidInterest, accInterest);
    }

    /// @dev pending repay debt because of EVMOS Unstaking's 14 days lock.
    /// Stayking should approve token first.
    function pendRepay(
        address user,
        uint256 amount
    ) public override onlyStayking returns(uint256 pendingDebtShare) {
        require(amount <= debtAmountOf[user], "pendRepay: too much amount to repay.");
        /// @dev subtract from debtAmountOf[user]
        unchecked {
            debtAmountOf[user] -= amount;
        }
        totalDebtAmount -= amount;

        /// @dev The pendingDebtAmount increases over time. 
        /// This is because lending interest is charged during the 14 days of unbonding.
        pendingDebtShare = pendingDebtAmountToShare(amount);
        pendingDebtShareOf[user] += pendingDebtShare;
        totalPendingDebtShare += pendingDebtShare;
        totalPendingDebtAmount += amount;
    }

    function getPendingDebt(
        address user
    ) public view override returns(uint256){
        return pendingDebtShareToAmount(pendingDebtShareOf[user]);
    }

    function getPendingDebtInBase(
        address user
    ) public view override returns(uint256){
        return getBaseIn(getPendingDebt(user));
    }

    /// @dev stayking should send with msg.value(= repayingDebt)
    function repayPendingDebt(
        address user,
        uint256 minRepaidDebt
    ) public payable override onlyStayking returns(uint256 repaidDebtAmount) {
        repaidDebtAmount = _swapFromBase(msg.value, minRepaidDebt);
        uint256 repaidDebtShare = pendingDebtAmountToShare(repaidDebtAmount);
        require(
            repaidDebtShare <= pendingDebtShareOf[user],
            "repayPendingDebt: too much msg.value to repay debt"
        );
        unchecked {
            pendingDebtShareOf[user] -= repaidDebtShare;
        }
    }

    /// @dev Fallback function to accept EVMOS.
    receive() external payable {}

    fallback() external payable {}
}