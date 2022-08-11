// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

interface IStakedEvmos { 

    event Lock(address user, uint256 lockedUntil);
    event Supply(uint256 amount);
    event Withdraw(address user, uint256 amount);

    function withdrawable() external view returns (uint256);

    function mintLockedToken(
        address to,
        uint256 lockedUntil
    ) external;

    function supplyUnstakedToken() payable external;

    function minter() external view returns(address);
    function setMinter(address newMinter) external;

}