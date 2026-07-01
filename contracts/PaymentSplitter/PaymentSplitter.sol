// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^4.9.0
pragma solidity ^0.8.29;

import "@openzeppelin/contracts@^4.9.0/finance/PaymentSplitter.sol";

contract RevenueSplitter is PaymentSplitter {

    constructor(address[] memory payees, uint256[] memory shares_) PaymentSplitter(payees, shares_) payable {}

    function release(address payable _to) public override {
        require(msg.sender == _to, "you can't transfer money");

        super.release(_to);
    }
} 