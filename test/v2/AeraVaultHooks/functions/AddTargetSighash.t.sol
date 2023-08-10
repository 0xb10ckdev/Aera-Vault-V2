// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultHooks.sol";

contract AddTargetSighashTest is TestBaseAeraVaultHooks {
    function test_addTargetSighash_fail_whenCallerIsNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(_USER);
        hooks.addTargetSighash(address(erc20Assets[0]), _TRANSFER_SELECTOR);
    }

    function test_addTargetSighash_success() public {
        TargetSighash targetSighash = TargetSighashLib.toTargetSighash(
            address(erc20Assets[0]), _TRANSFER_SELECTOR
        );

        assertFalse(hooks.targetSighashAllowed(targetSighash));

        vm.expectEmit(true, true, true, true, address(hooks));
        emit TargetSighashAdded(address(erc20Assets[0]), _TRANSFER_SELECTOR);

        hooks.addTargetSighash(address(erc20Assets[0]), _TRANSFER_SELECTOR);

        assertTrue(hooks.targetSighashAllowed(targetSighash));
    }
}
