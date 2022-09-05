// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "../lib/interface/IERC20.sol";
import "../lib/utils/SafeToken.sol";
import "../lib/Ownable.sol";


contract MockSwap is Ownable {
    
    /**
        @dev 본 컨트랙트는 로컬 노드 배포용 컨트랙트로,
        EvmoSwapRouter과 유사한 역할을 하는 DEX라고 생각하면 됩니다.

        native token(EVMOS)과 나머지 모든 토큰의 교환비는 임의로 1: 2라고 놓았습니다.
        (EVMOS의 가치 = 다른 토큰의 가치 * 2)

        TODO 배포 후 본 컨트랙트로 유동성 추가해 주어야 함.
        ex) IERC20(tokenAddress).mint(address(this), MAX_UINT / 2);
     */

    mapping(address => bool) public isSupported;
    uint256 public EVMOSpriceBps;

    constructor (
        address[] memory tokens
    ){
        for (uint256 i = 0; i < tokens.length; i++) {
            isSupported[tokens[i]] = true;
        }

        EVMOSpriceBps = 20000;
    }

    function getDx(
        address tokenX,
        address tokenY,
        uint256 dy
    ) public view returns (uint256) {
        if(tokenX == address(0))
            return dy * 1E4 / EVMOSpriceBps;
        else if(tokenY == address(0))
            return dy * EVMOSpriceBps / 1E4;
        else
            return dy;
    }

    function getDy(
        address tokenX,
        address tokenY,
        uint256 dx
    ) public view returns (uint256) {
        if(tokenX == address(0))
            return dx * EVMOSpriceBps / 1E4;
        else if(tokenY == address(0))
            return dx * 1E4 / EVMOSpriceBps;
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

    // sweep in-contract EVMOS
    function sweep() public onlyOwner {
        SafeToken.safeTransferEVMOS(msg.sender, address(this).balance);
    }

    function changeRatio(
        uint256 newRatio
    ) public onlyOwner {
        require(newRatio > 0, "newRatio <= 0");
        EVMOSpriceBps = newRatio;
    }

    fallback() external payable {}

    /// @dev Fallback function to accept EVMOS.
    receive() external payable {}
}