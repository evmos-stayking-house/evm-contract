// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;


interface IVault { 

    event Deposit(address user, uint256 amount);
    event Withdraw(address user, uint256 amount);
    event Loan(address user, uint256 amount);
    event Repay(address user, uint256 amount);
    event PayInterest(uint256 totalDebt, uint256 interest);
    event TransferDebtOwnership(address from, address to, uint256 amount);
    event UtilizationRate(uint256 rateBps);

    function baseTokenAddress() external returns(address);

    function utilizationRateBps() external view returns(uint256);

    function getInterestRateBps() external view returns(uint256);

    function saveUtilizationRateBps() external;

    function deposit(uint256 amount) external;

    function withdraw(uint256 share) external;

    function repay(
        address user,
        uint256 amount
    ) external;

    /******************************
     * Only for Stayking Contract *
     ******************************/
    function loan(
        address user,
        uint256 amount
    ) external;

    function takeDebtOwnership(
        address from,
        uint256 amount
    ) external;

    function payInterest() external;

    function updateStayking(
        address newStaykingAddress
    ) external;

}