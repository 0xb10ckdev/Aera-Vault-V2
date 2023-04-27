// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseCustody.sol";

abstract contract BasePauseVaultTest is TestBaseCustody {
    function test_pauseVault_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        custody.pauseVault();
    }

    function test_pauseVault_fail_whenVaultIsPaused() public {
        custody.pauseVault();

        vm.expectRevert(ICustody.Aera__VaultIsPaused.selector);

        custody.pauseVault();
    }

    function test_pauseVault_success() public virtual {
        vm.expectEmit(true, true, true, true, address(custody));
        emit PauseVault();

        custody.pauseVault();
    }
}
