// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;


interface IVault { 

    event Deposit(address user, uint256 amount, uint256 share);
    event Withdraw(address user, uint256 amount, uint256 share);
    event Loan(address user, uint256 amount);
    event Repay(address user, uint256 amount);
    event PayInterest(uint256 totalDebt, uint256 interest);
    event TransferDebtOwnership(address from, address to, uint256 amount);
    event UtilizationRate(uint256 rateBps);

    function token() external returns(address);
    
    function stayking() external returns(address);

    function interestModel() external returns(address);

    function totalAmount() external view returns(uint256);

    function totalDebt() external view returns(uint256);

    function utilizationRateBps() external view returns(uint256);

    /// @dev denominator = 1E18 
    function getInterestRate() external view returns(uint256);

    function saveUtilizationRateBps() external;

    function deposit(uint256 amount) external returns(uint256);

    function withdraw(uint256 share) external returns(uint256);

    /******************************
     * Only for Stayking Contract *
     ******************************/
    function loan(
        address user,
        uint256 amount
    ) external;

    function repay(
        address user,
        uint256 amount
    ) external;

    function takeDebtOwnership(
        address from,
        uint256 amount
    ) external;

    function payInterest() external;

    function updateStayking(address newStaykingAddress) external;

    function updateMinReservedBps(uint256 newMinReservedBps) external;
}