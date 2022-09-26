// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

/************************************************************
 * @dev
 * Glossary
 * X : Input Token
 * Y : Output Token
 * Dx : Amount of Input Token
 * Dy : Amount of Output Token
 *************************************************************/
interface ISwapHelper {
    function getDy(
        address tokenX,
        address tokenY,
        uint256 dx
    ) external view returns (uint256 dy);

    function getDx(
        address tokenX,
        address tokenY,
        uint256 dy
    ) external view returns (uint256 dx);

    function exchange(
        address tokenX,
        address tokenY,
        uint256 dx,
        uint256 minDy
    ) external payable returns (uint256 dy);
}
