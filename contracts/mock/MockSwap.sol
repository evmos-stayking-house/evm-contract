// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../lib/interface/IERC20.sol";
import "../lib/utils/SafeToken.sol";


contract MockSwap {
    
    /**
        @dev 본 컨트랙트는 로컬 노드 배포용 컨트랙트로,
        EvmoSwapRouter과 유사한 역할을 하는 DEX라고 생각하면 됩니다.

        native token(EVMOS)과 나머지 모든 토큰의 교환비는 임의로 1: 2라고 놓았습니다.
        (EVMOS의 가치 = 다른 토큰의 가치 * 2)

        TODO 배포 후 본 컨트랙트로 유동성 추가해 주어야 함.
        ex) IERC20(tokenAddress).mint(address(this), MAX_UINT / 2);
     */

    mapping(address => bool) public isSupported;

    constructor (
        address[] memory tokens
    ){
        for (uint256 i = 0; i < tokens.length; i++) {
            isSupported[tokens[i]] = true;
        }
    }

    function getDx(
        address tokenX,
        address tokenY,
        uint256 dy
    ) public pure returns (uint256) {
        if(tokenX == address(0))
            return dy / 2;
        else if(tokenY == address(0))
            return dy * 2;
        else
            return dy;
    }

    function getDy(
        address tokenX,
        address tokenY,
        uint256 dx
    ) public pure returns (uint256) {
        if(tokenX == address(0))
            return dx * 2;
        else if(tokenY == address(0))
            return dx / 2;
        else
            return dx;
    }

    function exchange(
        address tokenX,
        address tokenY,
        uint256 dx,
        uint256 /* minDy */
    ) public payable returns(uint256 dy) {
        if(tokenX == address(0)){
            require(msg.value == dx, "MockSwap: msg.value != dx");
        } else {
            SafeToken.safeTransferFrom(tokenX, msg.sender, address(this), dx);
        }

        dy = getDy(tokenX, tokenY, dx);
        if(tokenY == address(0)){
            SafeToken.safeTransferEVMOS(msg.sender, dy);
        } else {
            SafeToken.safeTransfer(tokenY, msg.sender, dy);
        }
    }

    /// @dev Fallback function to accept EVMOS.
    receive() external payable {}
}