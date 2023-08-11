// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAeraVaultV2.sol";

contract PauseTest is TestBaseAeraVaultV2 {
    event Paused(address);

    function test_pause_fail_whenCallerIsNotOwnerOrGuardian() public {
        vm.expectRevert(ICustody.Aera__CallerIsNotOwnerAndGuardian.selector);

        vm.prank(_USER);
        vault.pause();
    }

    function test_pause_fail_whenFinalized() public {
        vault.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        vault.pause();
    }

    function test_pause_fail_whenVaultIsPaused() public {
        vault.pause();

        vm.expectRevert("Pausable: paused");

        vault.pause();
    }

    function test_pause_success_whenOraclePriceIsInvalid() public {
        _setInvalidOracle(nonNumeraireId);

        vm.expectEmit(true, true, true, true, address(vault));
        emit Paused(_GUARDIAN);

        vm.prank(_GUARDIAN);
        vault.pause();
    }

    function test_pause_success() public {
        vm.expectEmit(true, true, true, true, address(vault));
        emit Paused(address(this));

        vault.pause();
    }

    function test_pause_success_withIncreasingFees() public {
        address feeRecipient = address(1);
        vault.setGuardianAndFeeRecipient(_USER, feeRecipient);

        assertEq(vault.feeTotal(), 0);
        assertEq(vault.fees(feeRecipient), 0);

        vm.warp(block.timestamp + 1000);

        vault.pause();

        assertEq(vault.feeTotal(), 499999);
        assertEq(vault.fees(feeRecipient), 499999);
    }
}
