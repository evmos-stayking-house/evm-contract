// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
import './interface/ISwapHelper.sol';
import './interface/swap/v2-periphery/IUniswapV2Router.sol';
import './lib/utils/SafeToken.sol';

contract SwapHelper is ISwapHelper {
    IUniswapV2Router public router;

    constructor(address _router) {
        router = IUniswapV2Router(payable(_router));
    }

    function getDy(
        address tokenX,
        address tokenY,
        uint256 dx
    ) public view override returns (uint256 dy) {
        address[] memory path = new address[](2);
        path[0] = tokenX == address(0) ? router.WETH() : tokenX;
        path[1] = tokenY == address(0) ? router.WETH() : tokenY;

        uint256[] memory amounts = router.getAmountsOut(dx, path);
        return amounts[1];
    }

    function getDx(
        address tokenX,
        address tokenY,
        uint256 dy
    ) public view override returns (uint256 dx) {
        address[] memory path = new address[](2);
        path[0] = tokenX == address(0) ? router.WETH() : tokenX;
        path[1] = tokenY == address(0) ? router.WETH() : tokenY;

        uint256[] memory amounts = router.getAmountsIn(dy, path);
        return amounts[0];
    }

    function exchange(
        address tokenX,
        address tokenY,
        uint256 dx,
        uint256 minDy
    ) public payable override returns (uint256) {
        address[] memory path = new address[](2);
        uint256[] memory amounts;

        // if tokenY == address(0) too, swapExactETHForTokens will be reverted.
        if (tokenX == address(0)) {
            require(dx == msg.value, 'exchange: invalid msg.value');

            path[0] = router.WETH();
            path[1] = tokenY;

            amounts = router.swapExactETHForTokens{value: dx}(
                minDy,
                path,
                msg.sender,
                block.timestamp + 600 // 10 minutes, 수치는 조절해야 함
            );

            return amounts[1];
        }
        else {
            /// @dev msg.sender should approve this helper contract first
            SafeToken.safeTransferFrom(tokenX, msg.sender, address(this), dx);

            SafeToken.safeApprove(tokenX, address(router), dx);

            path[0] = tokenX;
            path[1] = router.WETH();

            amounts = router.swapExactTokensForETH(
                dx,
                minDy,
                path,
                msg.sender,
                block.timestamp + 600 // 10 minutes, 수치는 조절해야 함
            );

            return amounts[1];
        }
    }

    
}
