// // SPDX-License-Identifier: UNLICENSED
// pragma solidity >=0.6.0 <0.8.0;

// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/utils/Pausable.sol";

// contract StayKingLeveragedPool is Ownable, Pausable {

//     mapping(address => uint) public delegators;
//     uint public minimumStakeCoin;
//     address payable public vault;

//     event Staked(address delegator, uint amount, uint when);
//     event NewVault(address masterWallet, uint when);

//     constructor (address _vault) public {
//         minimumStakeCoin = 0.1 ether;
//         vault = payable(_vault);
//     }

//     function enterStaking() public payable {}

//     function leaveStaking() public {}

//     function setVault(address payable _vault) public onlyOwner {
//         vault = _vault;
//         emit NewVault(address(vault), block.timestamp);
//     }
// }
