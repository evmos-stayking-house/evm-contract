// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "../interface/IVault.sol";
import "../interface/IInterestModel.sol";
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

    address public override token;
    address public override stayking;
    address public override interestModel;

    // Debt Amounts
    mapping(address => uint256) public override debtAmountOf;
    uint256 public override totalDebt;
    /// @dev totalShare == totalSupply()

    uint256 minReservedBps;
    uint256 yesterdayUtilRate;

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
        return IERC20(token).balanceOf(address(this)) + totalDebt;
    }

    function updateMinReservedBps(uint256 newMinReservedBps) onlyOwner public override {
        minReservedBps = newMinReservedBps;
    }

    function updateStayking(address newStaykingAddress) onlyOwner public override {
        stayking = newStaykingAddress;
    }

    /// @dev denominator = 1E18 
    function getInterestRate() public override view returns(uint256 interestRate){
        interestRate = IInterestModel(interestModel)
            .calcInterestRate(
                totalDebt,
                IERC20(token).balanceOf(address(this))
            );
    }

    function utilizationRateBps() public override view returns(uint256){
        return 1E4 * totalDebt / totalSupply();
    }

    function saveUtilizationRateBps() public override {
        if (block.timestamp >= lastSavedUtilizationRateTime + 1 days) {
            yesterdayUtilRate = utilizationRateBps();
            lastSavedUtilizationRateTime += 1 days;
            emit UtilizationRate(yesterdayUtilRate);
        }
    }
    
    /************************************
     * interface IVault Implementations
     ************************************/

    /// @notice user approve should be preceded
    function deposit(uint256 amount) public override returns(uint256 share) {
        uint256 beforeTotalAmount = totalAmount();
        share = beforeTotalAmount == 0 ? amount : amount * totalSupply() / beforeTotalAmount;
        
        SafeToken.safeTransferFrom(token, msg.sender, address(this), amount);
        _mint(msg.sender, share);

        emit Deposit(msg.sender, amount, share);
    }

    function withdraw(uint256 share) public override returns(uint256 amount){
        amount = share * totalAmount() / totalSupply();
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
        totalDebt += amount;
        require(
            totalDebt * 1E4 <= totalAmount() * minReservedBps,
            "Loan: Cant' loan debt anymore."
        );
        SafeToken.safeTransfer(token, stayking, amount);
        emit Loan(user, amount);
    }

    /// @dev Repay user's debt.
    /// Stayking should approve token first.
    function repay(
        address user,
        uint256 amount
    ) public override onlyStayking {
        debtAmountOf[user] -= amount;
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

    function payInterest() public override onlyStayking {
        uint256 interest = totalDebt * getInterestRate() / 1E18;
        SafeToken.safeTransferFrom(token, msg.sender, address(this), interest);
        emit PayInterest(totalDebt, interest);
    }  
}