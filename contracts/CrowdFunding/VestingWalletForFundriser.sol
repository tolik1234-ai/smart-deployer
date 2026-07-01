// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import "@openzeppelin/contracts/finance/VestingWallet.sol"; 

contract VestingWalletForFundriser is VestingWallet {

    constructor(address _beneficiary, uint64 _start, uint64 _duration) VestingWallet(_beneficiary, _start, _duration) {}
}