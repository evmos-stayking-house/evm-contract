// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;


interface IVault { 

    function token() external returns(address);
    
    function stayking() external returns(address);

    function interestModel() external returns(address);

    function totalAmount() external view returns(uint256);

    function debtAmountOf(address user) external view returns(uint256);

    function totalDebtAmount() external view returns(uint256);

    function utilizationRateBps() external view returns(uint256);

    /// @dev denominator = 1E18 
    function getInterestRate() external view returns(uint256);

    function saveUtilizationRateBps() external;

    function deposit(uint256 amount) external returns(uint256);

    function withdraw(uint256 share) external returns(uint256);

    /******************************
     * Only for Stayking Contract *
     ******************************/
    function loan(address user, uint256 amount) external;

    function repay(address user, uint256 amount) external;

    function takeDebtOwnership(
        address from,
        uint256 amount
    ) external;

    function payInterest() external payable;

    function pendRepay(address user, uint256 instantRepayment) external;

    function calcPendingDebtInBase(address user) external view returns(uint256);

    function repayPendingDebt(address user, uint256 minRepaidDebt) payable external;

    function updateStayking(address newStaykingAddress) external;

    function updateMinReservedBps(uint256 newMinReservedBps) external;
}