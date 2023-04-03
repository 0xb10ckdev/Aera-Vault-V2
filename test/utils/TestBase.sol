// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Test} from "forge-std/Test.sol";

contract TestBase is Test {
    uint256 internal constant _ONE = 1e18;
    address internal constant _USER = address(0xabcdef);
}
