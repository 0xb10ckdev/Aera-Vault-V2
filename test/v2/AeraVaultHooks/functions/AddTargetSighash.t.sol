// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAeraVaultHooks.sol";

contract AddTargetSighashTest is TestBaseAeraVaultHooks {
    function test_addTargetSighash_fail_whenCallerIsNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(_USER);
        hooks.addTargetSighash(
            address(erc20Assets[0]), IERC20.transfer.selector
        );
    }

    function test_addTargetSighash_success() public {
        TargetSighashData memory targetSighash = TargetSighashData({
            target: address(erc20Assets[0]),
            selector: IERC20.transfer.selector
        });

        assertFalse(
            hooks.targetSighashAllowed(
                targetSighash.target, targetSighash.selector
            )
        );

        vm.expectEmit(true, true, true, true, address(hooks));
        emit TargetSighashAdded(
            address(erc20Assets[0]), IERC20.transfer.selector
        );

        hooks.addTargetSighash(
            address(erc20Assets[0]), IERC20.transfer.selector
        );

        assertTrue(
            hooks.targetSighashAllowed(
                targetSighash.target, targetSighash.selector
            )
        );
    }
}
