// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {TargetSighash} from "src/v2/Types.sol";
import "src/v2/TargetSighashLib.sol";

contract TestTargetSigHashLib is Test {
    function testCollision() public {
        address A = 0x1234567890123456789012345678901234567890;
        address B = address((uint160(A) << 32) >> 32);
        bytes4 selector = bytes4(keccak256("foo()"));

        TargetSighash hashA = TargetSighashLib.toTargetSighash(A, selector);
        TargetSighash hashB = TargetSighashLib.toTargetSighash(B, selector);

        assertNotEq(TargetSighash.unwrap(hashA), TargetSighash.unwrap(hashB));
    }
}
