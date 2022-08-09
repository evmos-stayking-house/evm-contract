// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;


interface IVault { 
    function baseTokenAddress() external returns(address);

    function utilizationRateBps() external view returns(uint256);

    function deposit(
        uint256 amount
    ) external;

    function withdraw(
        uint256 share
    ) external;

    function loan(
        address user,
        uint256 amount
    ) external;

    function updateStayking(
        address newStaykingAddress
    ) external;

}