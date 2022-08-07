// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;

import "./libs/Ownable.sol";

contract StayKingVault is Ownable {
    mapping(address => uint) public delegators;
    uint public minimumStakeCoin;
    address payable public masterWallet;

    event Staked(address delegator, uint amount, uint when);
    event SweepCoin(address validator, uint amount, uint when);
    event NewMasterWallet(address masterWallet, uint when);

    constructor (address _masterWallet) {
        minimumStakeCoin = 0.1 ether;
        masterWallet = _masterWallet;
    }

    function stake() public {
        require(msg.value < 0.1 ether, "the balance of staking is bigger than 0.1 aevmos");
        delegators[payable(msg.sender)] += msg.value;
        emit Staked(address(msg.sender), delegators[address(msg.sender)], block.timestamp);
    }

    function sweep() public onlyOwner {
        payable(masterWallet).transfer(address(this).balance);
        emit SweepCoin(msg.sender, address(this).balance, block.timestamp);
    }

    function claim() public {
        // TBD...
    }

    function setMasterWallet(address payable _newMasterWallet) public onlyOwner {
        masterWallet = _newMasterWallet;
        emit NewMasterWallet(masterWallet, block.timestamp);
    }

}
