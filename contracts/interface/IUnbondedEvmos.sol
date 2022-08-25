// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.3;

interface IUnbondedEvmos { 

    function balanceOf(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function lastUnbondedAt() external view returns (uint256);

    function unbondingInterval() external view returns (uint256);

    function mintLockedToken(
        address to,
        address vault,
        uint256 amount,
        uint256 debtShare
    ) external;

    function unlock(uint256 minRepaid) external;

    function supplyUnbondedToken() payable external;

    function isMinter(address account) external view returns(bool);
    
    function updateMinterStatus(address account, bool status) external;

    function getUnlockable(address account) external view returns(uint256 unlockable, uint256 debt);

    function isKillable(uint256 lockedId) external returns (bool);

    function kill(uint256 lockedId) external;
}   