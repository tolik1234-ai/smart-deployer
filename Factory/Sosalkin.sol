// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts ^5.4.0
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts@5.4.0/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts@5.4.0/token/ERC20/extensions/ERC20Permit.sol";

contract Sosalkin is ERC20, ERC20Permit {
    constructor(address recipient)
        ERC20("Sosalkin", "SOSAL")
        ERC20Permit("Sosalkin")
    {
        _mint(recipient, 100000 * 10 ** decimals());
    }
}