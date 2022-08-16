// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../interface/ISwapHelper.sol";
import "./MockSwap.sol";


contract MockSwapHelper is ISwapHelper {

    MockSwap public swap;
    constructor(address swap_){
        swap = MockSwap(swap_);
    }

    function getDy(
        address tokenX,
        address tokenY,
        uint256 dx
    ) public override view returns (uint256 dy) {
        return swap.getDy(tokenX, tokenY, dx);
    }

    function getDx(
        address tokenX,
        address tokenY,
        uint256 dy
    ) public override view returns (uint256 dx) {
        return swap.getDx(tokenX, tokenY, dy);
    }

    function exchange(
        address tokenX,
        address tokenY,
        uint256 dx,
        uint256 minDy
    ) public payable override returns (uint256 dy){
        if(tokenX == address(0)){
            require(msg.value == dx, "MockSwap: msg.value != dx");
        } else {
            SafeToken.safeTransferFrom(tokenX, msg.sender, address(this), dx);
        }

        dy = swap.exchange(tokenX, tokenY, dx, minDy);

        if(tokenY == address(0)){
            SafeToken.safeTransferEVMOS(msg.sender, dy);
        } else {
            SafeToken.safeTransfer(tokenY, msg.sender, dy);
        }
    }
}