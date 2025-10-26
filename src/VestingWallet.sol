// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/finance/VestingWallet.sol";

contract VestWallet is VestingWallet {

    constructor(address _beneficiary, uint64 _duration) VestingWallet(_beneficiary, uint64(block.timestamp), _duration) payable {}
}