// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";

contract UnpauseVaultTest is TestBaseAeraVaultV2 {
    event Unpaused(address);

    function test_unpauseVault_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        vault.unpauseVault();
    }

    function test_unpauseVault_fail_whenFinalized() public {
        vault.pauseVault();
        vault.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        vault.unpauseVault();
    }

    function test_unpauseVault_fail_whenVaultIsNotPaused() public {
        vm.expectRevert(bytes("Pausable: not paused"));

        vault.unpauseVault();
    }

    function test_unpauseVault_success() public virtual {
        vault.pauseVault();

        vm.expectEmit(true, true, true, true, address(vault));
        emit Unpaused(address(this));

        vault.unpauseVault();
    }
}
