// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseCustody.sol";

abstract contract BaseUnpauseVaultTest is TestBaseCustody {
    event Unpaused(address);

    function test_unpauseVault_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        custody.unpauseVault();
    }

    function test_unpauseVault_fail_whenFinalized() public {
        custody.pauseVault();
        custody.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        custody.unpauseVault();
    }

    function test_unpauseVault_fail_whenVaultIsNotPaused() public {
        vm.expectRevert(bytes("Pausable: not paused"));

        custody.unpauseVault();
    }

    function test_unpauseVault_success() public virtual {
        custody.pauseVault();

        vm.expectEmit(true, true, true, true, address(custody));
        emit Unpaused(address(this));

        custody.unpauseVault();
    }
}
