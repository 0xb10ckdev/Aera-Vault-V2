// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test} from "forge-std/Test.sol";

contract Invariants is Test {
    function setUp() public {
        targetContract(address(0x0));
    }
}
