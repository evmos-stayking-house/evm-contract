// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


interface IStayKingLendingPool is Ownable, Pausable {

    function deposit(uint256 _amount) external whenNotPaused notContract;

    function withdraw() external whenNotPaused notContract;

    function loan() external whenNotPaused notContract;

    function _calculateInterest() internal;
}
