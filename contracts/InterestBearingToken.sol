// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/*
 @title Lending Pool 에 Evmos 를 맡길 때 1:1로 발급할 ibToken
 @dev
*/
contract InterestBearingToken is ERC20 {

    constructor(
        string memory name,
        string memory symbol,
        uint256 supply
    ) public ERC20(name, symbol) {
        _mint(msg.sender, supply);
    }

    function mintTokens(uint256 _amount) external {
        _mint(msg.sender, _amount);
    }

    function burnTokens(uint256 _amount) external {
        _burn(msg.sender, _amount);
    }
}
