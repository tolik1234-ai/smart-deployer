// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/finance/PaymentSplitter.sol";

contract RevenueSplitter is PaymentSplitter {

    constructor(address[] memory payees, uint256[] memory shares_) PaymentSplitter(payees, shares_) payable {}

    // error OnlyTheRecipientCanRelease();

    // function receive() external payable {}

    // function release(address payable _to) public override {
    //     require(msg.sender == _to, OnlyTheRecipientCanRelease());
        
    //     super.release(_to);
    //}
}