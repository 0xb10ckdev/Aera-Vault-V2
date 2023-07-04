// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultHooks.sol";

contract RemoveTargetSighashTest is TestBaseAeraVaultHooks {
    function test_removeTargetSighash_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        hooks.removeTargetSighash(address(erc20Assets[0]), _TRANSFER_SELECTOR);
    }

    function test_removeTargetSighash_success() public {
        TargetSighash targetSighash = TargetSighashLib.toTargetSighash(
            address(erc20Assets[0]), _TRANSFER_SELECTOR
        );

        hooks.addTargetSighash(address(erc20Assets[0]), _TRANSFER_SELECTOR);

        assertTrue(hooks.targetSighashAllowlist(targetSighash));

        vm.expectEmit(true, true, true, true, address(hooks));
        emit RemoveTargetSighash(address(erc20Assets[0]), _TRANSFER_SELECTOR);

        hooks.removeTargetSighash(address(erc20Assets[0]), _TRANSFER_SELECTOR);

        assertFalse(hooks.targetSighashAllowlist(targetSighash));
    }
}
