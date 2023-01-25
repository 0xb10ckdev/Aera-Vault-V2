// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Dummy.sol";

contract DummyTest is Test {
    Dummy public dummy;

    function setUp() public {
        dummy = new Dummy();
    }

    function testDummy() public {
        assertTrue(dummy.isDummy());
    }
}
