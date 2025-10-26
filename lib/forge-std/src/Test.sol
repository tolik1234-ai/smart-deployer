// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract Test {
    function fail() internal pure {
        require(false, "Test: failure triggered");
    }
}
