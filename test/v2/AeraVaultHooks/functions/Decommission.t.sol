// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAeraVaultHooks.sol";

contract DecommissionTest is TestBaseAeraVaultHooks {
    function test_decommission_fail_whenCallerIsNotVault() public {
        vm.expectRevert(AeraVaultHooks.Aera__CallerIsNotVault.selector);

        vm.prank(_USER);
        hooks.decommission();
    }

    function test_decommission_success() public {
        assertEq(hooks.vault(), address(vault));

        vm.expectEmit(true, true, true, true, address(hooks));
        emit Decommissioned();

        vm.prank(address(vault));
        hooks.decommission();

        assertEq(hooks.vault(), address(0));
    }
}
