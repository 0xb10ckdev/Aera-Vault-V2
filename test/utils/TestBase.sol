// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";

contract TestBase is Test {
    uint256 internal constant ONE = 1e18;
    address internal constant USER = address(0xabcdef);
}
