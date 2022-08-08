/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../../common";
import type {
  StayKingLendingPool,
  StayKingLendingPoolInterface,
} from "../../contracts/StayKingLendingPool";

const _abi = [
  {
    inputs: [
      {
        internalType: "contract IERC20",
        name: "_ibToken",
        type: "address",
      },
      {
        internalType: "address",
        name: "_vault",
        type: "address",
      },
    ],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "sender",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "shares",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "lastDepositedTime",
        type: "uint256",
      },
    ],
    name: "Deposit",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "sender",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "interestRate",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "lastLoanedTime",
        type: "uint256",
      },
    ],
    name: "Loan",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "previousOwner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "OwnershipTransferred",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "Paused",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "sender",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "interestRate",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "lastRepayedTime",
        type: "uint256",
      },
    ],
    name: "Repay",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: "address",
        name: "account",
        type: "address",
      },
    ],
    name: "Unpaused",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "sender",
        type: "address",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        indexed: false,
        internalType: "uint256",
        name: "shares",
        type: "uint256",
      },
    ],
    name: "Withdraw",
    type: "event",
  },
  {
    inputs: [],
    name: "MAX_INTEREST_RATE",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "MAX_LOAN_INTEREST_RATE",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "_address",
        type: "address",
      },
    ],
    name: "balanceOf",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "borrowerInfo",
    outputs: [
      {
        internalType: "uint256",
        name: "amount",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "interestRate",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "lastLoanedTime",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "lastRepayedTime",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "deposit",
    outputs: [],
    stateMutability: "payable",
    type: "function",
  },
  {
    inputs: [],
    name: "ibToken",
    outputs: [
      {
        internalType: "contract IERC20",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "interestRate",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_amount",
        type: "uint256",
      },
    ],
    name: "loan",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "loanInterestRate",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "owner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "paused",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "renounceOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "repay",
    outputs: [],
    stateMutability: "payable",
    type: "function",
  },
  {
    inputs: [],
    name: "totalShares",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "transferOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    name: "userInfo",
    outputs: [
      {
        internalType: "uint256",
        name: "shares",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "lastDepositedTime",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "evmosAtLastUserAction",
        type: "uint256",
      },
      {
        internalType: "uint256",
        name: "lastUserActionTime",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "_shares",
        type: "uint256",
      },
    ],
    name: "withdraw",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const _bytecode =
  "0x60806040526113886001556103e86002556105dc60035534801561002257600080fd5b50604051611dc9380380611dc98339818101604052604081101561004557600080fd5b81019080805190602001909291908051906020019092919050505060006100706101b160201b60201c565b9050806000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055508073ffffffffffffffffffffffffffffffffffffffff16600073ffffffffffffffffffffffffffffffffffffffff167f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e060405160405180910390a35060008060146101000a81548160ff02191690831515021790555081600460006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff16021790555080600660006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff16021790555050506101b9565b600033905090565b611c01806101c86000396000f3fe6080604052600436106100fe5760003560e01c806370a08231116100955780638da5cb5b116100645780638da5cb5b146103ab578063c222bcea14610402578063ca103d151461042d578063d0e30db0146104a7578063f2fde38b146104b1576100fe565b806370a08231146102d9578063715018a61461033e57806372747df3146103555780637c3a00fd14610380576100fe565b8063365a5306116100d1578063365a53061461023a5780633a98ef3914610275578063402d8883146102a05780635c975abb146102aa576100fe565b80630a8a5a5f146101035780631959a0021461015a5780632e1a7d4d146101d457806334855d141461020f575b600080fd5b34801561010f57600080fd5b50610118610502565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b34801561016657600080fd5b506101a96004803603602081101561017d57600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff169060200190929190505050610528565b6040518085815260200184815260200183815260200182815260200194505050505060405180910390f35b3480156101e057600080fd5b5061020d600480360360208110156101f757600080fd5b8101908080359060200190929190505050610558565b005b34801561021b57600080fd5b50610224610b00565b6040518082815260200191505060405180910390f35b34801561024657600080fd5b506102736004803603602081101561025d57600080fd5b8101908080359060200190929190505050610b06565b005b34801561028157600080fd5b5061028a610db9565b6040518082815260200191505060405180910390f35b6102a8610dbf565b005b3480156102b657600080fd5b506102bf61107e565b604051808215151515815260200191505060405180910390f35b3480156102e557600080fd5b50610328600480360360208110156102fc57600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff169060200190929190505050611094565b6040518082815260200191505060405180910390f35b34801561034a57600080fd5b506103536110b5565b005b34801561036157600080fd5b5061036a611223565b6040518082815260200191505060405180910390f35b34801561038c57600080fd5b50610395611229565b6040518082815260200191505060405180910390f35b3480156103b757600080fd5b506103c061122f565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b34801561040e57600080fd5b50610417611258565b6040518082815260200191505060405180910390f35b34801561043957600080fd5b5061047c6004803603602081101561045057600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff16906020019092919050505061125e565b6040518085815260200184815260200183815260200182815260200194505050505060405180910390f35b6104af61128e565b005b3480156104bd57600080fd5b50610500600480360360208110156104d457600080fd5b81019080803573ffffffffffffffffffffffffffffffffffffffff1690602001909291905050506116fa565b005b600460009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b60076020528060005260406000206000915090508060000154908060010154908060020154908060030154905084565b61056061107e565b156105d3576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260108152602001807f5061757361626c653a207061757365640000000000000000000000000000000081525060200191505060405180910390fd5b6105dc336118ed565b1561064f576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260148152602001807f636f6e7472616374206e6f7420616c6c6f77656400000000000000000000000081525060200191505060405180910390fd5b3273ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff16146106f0576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252601a8152602001807f70726f787920636f6e7472616374206e6f7420616c6c6f77656400000000000081525060200191505060405180910390fd5b6000600760003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000209050600082116107a9576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260138152602001807f4e6f7468696e6720746f2077697468647261770000000000000000000000000081525060200191505060405180910390fd5b8060000154821115610823576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252601f8152602001807f576974686472617720616d6f756e7420657863656564732062616c616e63650081525060200191505060405180910390fd5b60006108546005546108468561083830611094565b61190090919063ffffffff16565b61198690919063ffffffff16565b9050600061086130611094565b9050818110156108d9576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260148152602001807f696e73756666696369656e7420706f6f6c2e2e2e00000000000000000000000081525060200191505060405180910390fd5b6108f0848460000154611a0f90919063ffffffff16565b836000018190555061090d84600554611a0f90919063ffffffff16565b6005819055506000836000015411156109605761095360055461094561093230611094565b866000015461190090919063ffffffff16565b61198690919063ffffffff16565b836002018190555061096b565b600083600201819055505b428360030181905550600460009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663a9059cbb30846040518363ffffffff1660e01b8152600401808373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200182815260200192505050602060405180830381600087803b158015610a1d57600080fd5b505af1158015610a31573d6000803e3d6000fd5b505050506040513d6020811015610a4757600080fd5b8101908080519060200190929190505050503373ffffffffffffffffffffffffffffffffffffffff166108fc839081150290604051600060405180830381858888f19350505050158015610a9f573d6000803e3d6000fd5b503373ffffffffffffffffffffffffffffffffffffffff167ff279e6a1f5e320cca91135676d9cb6e44ca8a08c0b88342bcdb1144f6511b568838560000154604051808381526020018281526020019250505060405180910390a250505050565b610bb881565b610b0e61107e565b15610b81576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260108152602001807f5061757361626c653a207061757365640000000000000000000000000000000081525060200191505060405180910390fd5b610b89611a92565b73ffffffffffffffffffffffffffffffffffffffff16610ba761122f565b73ffffffffffffffffffffffffffffffffffffffff1614610c30576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260208152602001807f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e657281525060200191505060405180910390fd5b478110610c88576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401808060200182810382526025815260200180611ba76025913960400191505060405180910390fd5b6000600860003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200190815260200160002090508181600001819055504281600201819055506003548160010181905550600660009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff166108fc839081150290604051600060405180830381858888f19350505050158015610d50573d6000803e3d6000fd5b503373ffffffffffffffffffffffffffffffffffffffff167fc2ad9b96e86958983d97154422c868748371d03ae876909d99253d917d1aa73083600254846002015460405180848152602001838152602001828152602001935050505060405180910390a25050565b60055481565b610dc761107e565b15610e3a576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260108152602001807f5061757361626c653a207061757365640000000000000000000000000000000081525060200191505060405180910390fd5b610e42611a92565b73ffffffffffffffffffffffffffffffffffffffff16610e6061122f565b73ffffffffffffffffffffffffffffffffffffffff1614610ee9576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260208152602001807f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e657281525060200191505060405180910390fd5b6000600860003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff168152602001908152602001600020905034600010610fa2576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260148152602001807f4e6f7468696e6720746f2072657061792e2e2e2e00000000000000000000000081525060200191505060405180910390fd5b34816000015414610ffe576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252603d815260200180611b49603d913960400191505060405180910390fd5b600081600001819055504281600301819055503373ffffffffffffffffffffffffffffffffffffffff167f2fe77b1c99aca6b022b8efc6e3e8dd1b48b30748709339b65c50ef3263443e0982600001548360010154846003015460405180848152602001838152602001828152602001935050505060405180910390a250565b60008060149054906101000a900460ff16905090565b60008173ffffffffffffffffffffffffffffffffffffffff16319050919050565b6110bd611a92565b73ffffffffffffffffffffffffffffffffffffffff166110db61122f565b73ffffffffffffffffffffffffffffffffffffffff1614611164576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260208152602001807f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e657281525060200191505060405180910390fd5b600073ffffffffffffffffffffffffffffffffffffffff166000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff167f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e060405160405180910390a360008060006101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff160217905550565b60015481565b60025481565b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff16905090565b60035481565b60086020528060005260406000206000915090508060000154908060010154908060020154908060030154905084565b61129661107e565b15611309576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260108152602001807f5061757361626c653a207061757365640000000000000000000000000000000081525060200191505060405180910390fd5b611312336118ed565b15611385576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260148152602001807f636f6e7472616374206e6f7420616c6c6f77656400000000000000000000000081525060200191505060405180910390fd5b3273ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614611426576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252601a8152602001807f70726f787920636f6e7472616374206e6f7420616c6c6f77656400000000000081525060200191505060405180910390fd5b6000341161149c576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260128152602001807f4e6f7468696e6720746f206465706f736974000000000000000000000000000081525060200191505060405180910390fd5b600034905060006114ac30611094565b905060008090506000600554146114eb576114e4826114d66005548661190090919063ffffffff16565b61198690919063ffffffff16565b90506114ef565b8290505b6000600760003373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020019081526020016000209050611549828260000154611a9a90919063ffffffff16565b816000018190555042816001018190555061156f82600554611a9a90919063ffffffff16565b6005819055506115a060055461159285846000015461190090919063ffffffff16565b61198690919063ffffffff16565b8160020181905550428160030181905550600460009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1663a9059cbb33866040518363ffffffff1660e01b8152600401808373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200182815260200192505050602060405180830381600087803b15801561165a57600080fd5b505af115801561166e573d6000803e3d6000fd5b505050506040513d602081101561168457600080fd5b8101908080519060200190929190505050503373ffffffffffffffffffffffffffffffffffffffff167f36af321ec8d3c75236829c5317affd40ddb308863a1236d2d277a4025cccee1e85844260405180848152602001838152602001828152602001935050505060405180910390a250505050565b611702611a92565b73ffffffffffffffffffffffffffffffffffffffff1661172061122f565b73ffffffffffffffffffffffffffffffffffffffff16146117a9576040517f08c379a00000000000000000000000000000000000000000000000000000000081526004018080602001828103825260208152602001807f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e657281525060200191505060405180910390fd5b600073ffffffffffffffffffffffffffffffffffffffff168173ffffffffffffffffffffffffffffffffffffffff16141561182f576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401808060200182810382526026815260200180611b236026913960400191505060405180910390fd5b8073ffffffffffffffffffffffffffffffffffffffff166000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff167f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e060405160405180910390a3806000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff16021790555050565b600080823b905060008111915050919050565b6000808314156119135760009050611980565b600082840290508284828161192457fe5b041461197b576040517f08c379a0000000000000000000000000000000000000000000000000000000008152600401808060200182810382526021815260200180611b866021913960400191505060405180910390fd5b809150505b92915050565b60008082116119fd576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252601a8152602001807f536166654d6174683a206469766973696f6e206279207a65726f00000000000081525060200191505060405180910390fd5b818381611a0657fe5b04905092915050565b600082821115611a87576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252601e8152602001807f536166654d6174683a207375627472616374696f6e206f766572666c6f77000081525060200191505060405180910390fd5b818303905092915050565b600033905090565b600080828401905083811015611b18576040517f08c379a000000000000000000000000000000000000000000000000000000000815260040180806020018281038252601b8152602001807f536166654d6174683a206164646974696f6e206f766572666c6f77000000000081525060200191505060405180910390fd5b809150509291505056fe4f776e61626c653a206e6577206f776e657220697320746865207a65726f206164647265737374686520616d6f756e74206f66207265706179206d75737420626520657175616c20746f20626f72726f77656420616d6f756e74206265666f72652e2e536166654d6174683a206d756c7469706c69636174696f6e206f766572666c6f77496e73756666696369656e7420706f6f6c2062616c616e636520666f72206c6f616e2e2e2ea2646970667358221220022c9dc690f7ccf2ad79c1e84acad1168c20c5a694a26fd8fbc83286d3d7f65a64736f6c63430006000033";

type StayKingLendingPoolConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: StayKingLendingPoolConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class StayKingLendingPool__factory extends ContractFactory {
  constructor(...args: StayKingLendingPoolConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    _ibToken: PromiseOrValue<string>,
    _vault: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<StayKingLendingPool> {
    return super.deploy(
      _ibToken,
      _vault,
      overrides || {}
    ) as Promise<StayKingLendingPool>;
  }
  override getDeployTransaction(
    _ibToken: PromiseOrValue<string>,
    _vault: PromiseOrValue<string>,
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(_ibToken, _vault, overrides || {});
  }
  override attach(address: string): StayKingLendingPool {
    return super.attach(address) as StayKingLendingPool;
  }
  override connect(signer: Signer): StayKingLendingPool__factory {
    return super.connect(signer) as StayKingLendingPool__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): StayKingLendingPoolInterface {
    return new utils.Interface(_abi) as StayKingLendingPoolInterface;
  }
  static connect(
    address: string,
    signerOrProvider: Signer | Provider
  ): StayKingLendingPool {
    return new Contract(address, _abi, signerOrProvider) as StayKingLendingPool;
  }
}
