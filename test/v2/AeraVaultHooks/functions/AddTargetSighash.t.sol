// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultHooks.sol";

contract AddTargetSighashTest is TestBaseAeraVaultHooks {
    function test_addTargetSighash_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        hooks.addTargetSighash(address(erc20Assets[0]), _TRANSFER_SELECTOR);
    }

    function test_addTargetSighash_success() public {
        TargetSighash targetSighash = TargetSighashLib.toTargetSighash(
            address(erc20Assets[0]), _TRANSFER_SELECTOR
        );

        assertFalse(hooks.targetSighashAllowlist(targetSighash));

        vm.expectEmit(true, true, true, true, address(hooks));
        emit AddTargetSighash(address(erc20Assets[0]), _TRANSFER_SELECTOR);

        hooks.addTargetSighash(address(erc20Assets[0]), _TRANSFER_SELECTOR);

        assertTrue(hooks.targetSighashAllowlist(targetSighash));
    }
}
