// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

interface IInterestModel {
    function calcInterestRate(uint256 debt, uint256 floating)
        external
        pure
        returns (uint256);
}