// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import 'hardhat/console.sol';
import '../interface/ISwapHelper.sol';
import './MockSwap.sol';

contract MockSwapHelper is ISwapHelper {
    MockSwap public swap;

    constructor(address payable swap_) {
        swap = MockSwap(swap_);
    }

    function getDy(
        address tokenX,
        address tokenY,
        uint256 dx
    ) public view override returns (uint256 dy) {
        return swap.getDy(tokenX, tokenY, dx);
    }

    function getDx(
        address tokenX,
        address tokenY,
        uint256 dy
    ) public view override returns (uint256 dx) {
        return swap.getDx(tokenX, tokenY, dy);
    }

    function exchange(
        address tokenX,
        address tokenY,
        uint256 dx,
        uint256 minDy
    ) public payable override returns (uint256 dy) {
        if (tokenX == address(0)) {
            require(msg.value == dx, 'MockSwap: msg.value != dx');
            dy = swap.exchange{value: dx}(tokenX, tokenY, dx, minDy);
        } else {
            SafeToken.safeTransferFrom(tokenX, msg.sender, address(this), dx);
            SafeToken.safeApprove(tokenX, address(swap), dx);
            dy = swap.exchange(tokenX, tokenY, dx, minDy);
        }

        if (tokenY == address(0)) {
            SafeToken.safeTransferEVMOS(msg.sender, dy);
        } else {
            SafeToken.safeTransfer(tokenY, msg.sender, dy);
        }
    }

    fallback() external payable {}

    receive() external payable {}
}
