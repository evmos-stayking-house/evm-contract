// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

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

    address public constant BASE_TOKEN = address(0);

    event Deposit(address user, uint256 amount, uint256 share);
    event Withdraw(address user, uint256 amount, uint256 share);
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
    uint256 totalPendingDebtShare;
    uint256 totalPendingDebtAmount;

    uint256 minReservedBps;
    uint256 yesterdayUtilRate;
    uint256 accInterest;

    uint lastSavedUtilizationRateTime;

    /*************
     * Modifiers *
    **************/

    modifier onlyStayking(){
        require(msg.sender == stayking, "Vault: Not Stayking contract.");
        _;
    }

    /****************
     * Initializer *
    *****************/

    function __Vault_init(
        string calldata _name,
        string calldata _symbol,
        address _stayking,
        address _token,
        address _interestModel,
        uint256 _minReservedBps
    ) external onlyInitializing {
        require(_stayking != address(0), "Vault: Stayking address is zero");
        require(_token != address(0), "Vault: Base Token is zero address");
        
        __ERC20_init(_name, _symbol);
        __Ownable_init();

        stayking = _stayking;
        token = _token;
        interestModel = _interestModel;
        minReservedBps = _minReservedBps;

        // @TODO changed
        lastSavedUtilizationRateTime = block.timestamp - 
            ((block.timestamp - 1639098000) % 1 days);
    }

    // @dev (token in vault) + (debt)
    function totalAmount() public override view returns(uint256){
        return IERC20(token).balanceOf(address(this)) + totalDebtAmount;
    }

    function updateMinReservedBps(uint256 newMinReservedBps) public override onlyOwner {
        minReservedBps = newMinReservedBps;
    }

    function updateStayking(address newStaykingAddress) public override onlyOwner {
        stayking = newStaykingAddress;
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

    function pendingDebtAmountToShare(
        uint256 amount
    ) public view returns(uint256) {
        return (totalPendingDebtAmount == 0) ? amount : 
            (totalPendingDebtShare * amount) / totalPendingDebtAmount;
    }

    function pendingDebtShareToAmount(
        uint256 share
    ) public view returns(uint256) {
        return (totalPendingDebtShare == 0) ? share : 
            (totalPendingDebtAmount * share) / totalPendingDebtShare;
    }

    /// @dev denominator = 1E18 
    function getInterestRate() public override view returns(uint256 interestRate){
        interestRate = IInterestModel(interestModel)
            .calcInterestRate(
                totalDebtAmount,
                IERC20(token).balanceOf(address(this))
            );
    }

    function utilizationRateBps() public override view returns(uint256){
        return 1E4 * totalDebtAmount / totalAmount();
    }

    function saveUtilizationRateBps() public override {
        if (block.timestamp >= lastSavedUtilizationRateTime + 1 days) {
            yesterdayUtilRate = utilizationRateBps();
            lastSavedUtilizationRateTime += 1 days;
            accInterest += (totalDebtAmount * getInterestRate() / 1E18);
            emit UtilizationRate(yesterdayUtilRate);
        }
    }
    
    /************************************
     * interface IVault Implementations
     ************************************/

    /// @notice user approve should be preceded
    function deposit(uint256 amount) public override returns(uint256 share){
        share = amountToShare(amount);
        SafeToken.safeTransferFrom(token, msg.sender, address(this), amount);
        _mint(msg.sender, share);

        emit Deposit(msg.sender, amount, share);
    }

    function withdraw(uint256 share) public override returns(uint256 amount){
        amount = shareToAmount(share);
        _burn(msg.sender, share);
        SafeToken.safeTransfer(token, msg.sender, amount);

        emit Withdraw(msg.sender, amount, share);
    }

    /// @notice loan is only for Stayking contract.
    function loan(
        address user,
        uint256 amount
    ) public override onlyStayking {
        debtAmountOf[user] += amount;
        totalDebtAmount += amount;
        require(
            totalDebtAmount * 1E4 <= totalAmount() * minReservedBps,
            "Loan: Cant' loan debt anymore."
        );
        SafeToken.safeTransfer(token, msg.sender, amount);
        emit Loan(user, amount);
    }

    // @TODO Should approve MAX_UINT?
    /// @dev Repay user's debt.
    /// Stayking should approve token first.
    function repay(
        address user,
        uint256 amount
    ) public override onlyStayking {
        debtAmountOf[user] -= amount;
        totalDebtAmount -= amount;
        SafeToken.safeTransferFrom(token, user, address(this), amount);
        emit Repay(user, amount);
    }

    function takeDebtOwnership(
        address from,
        uint256 amount
    ) public override onlyStayking {
        debtAmountOf[from] -= amount;
        debtAmountOf[msg.sender] += amount;
        emit TransferDebtOwnership(from, msg.sender, amount);
    }

    function payInterest() public payable override onlyStayking {
        uint256 paidInterest = swapHelper.exchange(BASE_TOKEN, token, msg.value, 1);
        require(accInterest >= paidInterest, "msg.value is greater than accumulated interest.");
        unchecked {
            accInterest -= paidInterest;
        }
        emit PayInterest(paidInterest, accInterest);
    }

    /// @dev pending repay debt because of EVMOS Unstaking's 14 days lock.
    /// @notice User can instantly repay some of their debts with their tokens.
    /// Stayking should approve token first.
    function pendRepay(
        address user,
        uint256 instantRepayment
    ) public override onlyStayking {
        if(instantRepayment > 0){
            repay(user, instantRepayment);
        }

        uint256 pendingDebtAmount = debtAmountOf[user];
        uint256 pendingDebtShare = pendingDebtAmountToShare(pendingDebtAmount);
        pendingDebtShareOf[user] = pendingDebtShare;
        totalPendingDebtShare += pendingDebtShare;
        totalPendingDebtAmount += pendingDebtAmount;
    }

    function calcPendingDebtInBase(
        address user
    ) public view override returns(uint256){
        return swapHelper.getDx(
            BASE_TOKEN, 
            token,
            pendingDebtShareToAmount(pendingDebtShareOf[user])
        );
    }

    /// @dev stayking should send with value: repayingDebt 
    function repayPendingDebt(
        address user,
        uint256 minRepaidDebt
    ) public payable override onlyStayking {

        uint256 repaidDebtAmount = swapHelper.exchange(BASE_TOKEN, token, msg.value, minRepaidDebt);
        require(
            repaidDebtAmount <= pendingDebtShareToAmount(pendingDebtShareOf[user]),
            "repayPendingDebt: too much msg.value to repay debt"
        );

        uint256 repaidDebtShare = pendingDebtAmountToShare(repaidDebtAmount);
        pendingDebtShareOf[user] -= repaidDebtShare;
    }
}