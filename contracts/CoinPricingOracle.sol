// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.6.0 <0.8.0;

import "./libs/provableAPI.sol";

contract OracleContract is usingProvable {
    // for storing the query ids
    bytes32 BTC_ID;
    bytes32 regular_ID;
    // for storing BTC and fuel price
    string public BTC_USD;
    string public FUEL_Price;
    // events
    event ValueUpdated(string price);
    event ProvableQueryCalled(string description);
    // save the address of the owner of this contract
    address payable owner = msg.sender;
    // callback for the query
    function __callback(bytes32 myid, string memory result) public
    override {
        // update only if you are the caller
        require(msg.sender == provable_cbAddress());
        if (myid == BTC_ID)
            BTC_USD = result;
        else if (myid == regular_ID)
            FUEL_Price = result;
        emit ValueUpdated(result);
    }
    // helper function to store 2 strings
    function compareStrings(string memory a, string memory b)
    private pure returns (bool) {
        return (keccak256(abi.encodePacked((a))) ==
        keccak256(abi.encodePacked((b))));
    }
    // call this function to access web services
    function updatePrice(string memory updateType) public payable {
        // only the owner can invoke this function
        require(msg.sender == owner,
            'Only the owner of this contract can call this function');
        if (provable_getPrice("URL") > address(this).balance) {
            emit ProvableQueryCalled("Please ensure that your wallet have sufficient funds to pay for the query");
        } else {
            emit ProvableQueryCalled("Query sent, please wait");
            if (compareStrings(updateType,"BTC"))
                BTC_ID = provable_query("URL", "json(https://api.pro.coinbase.com/products/BTC-USD/ticker).price");
            if (compareStrings(updateType,"FUEL"))
                regular_ID = provable_query("URL",
                    "xml(https://www.fueleconomy.gov/ws/rest/fuelprices).fuelPrices.regular");
        }
    }
    function refund() public {
        require(msg.sender == owner,
            'Only the owner of this contract can call this function');
        // refund back to the owner the funds in the contract
        owner.transfer(address(this).balance);
    }
    receive() external payable {}
}

