// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";

contract ResumeTest is TestBaseAeraVaultV2 {
    event Unpaused(address);

    function test_resume_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        vault.resume();
    }

    function test_resume_fail_whenHooksIsNotSet() public {
        vault.pause();
        vm.store(
            address(vault),
            bytes32(uint256(4)), // storage slot of hooks
            bytes32(uint256(0))
        );
        vm.expectRevert(ICustody.Aera__HooksIsZeroAddress.selector);
        vault.resume();
    }

    function test_resume_fail_whenFinalized() public {
        vault.pause();
        vault.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        vault.resume();
    }

    function test_resume_fail_whenVaultIsNotPaused() public {
        vm.expectRevert(bytes("Pausable: not paused"));

        vault.resume();
    }

    function test_resume_success() public {
        vault.pause();

        vm.expectEmit(true, true, true, true, address(vault));
        emit Unpaused(address(this));

        vault.resume();
    }

    function test_resume_does_not_increase_fees() public {
        vault.pause();

        address feeRecipient = address(1);
        vault.setGuardianAndFeeRecipient(_USER, feeRecipient);

        assertEq(vault.feeTotal(), 0);
        assertEq(vault.fees(feeRecipient), 0);

        vm.warp(block.timestamp + 1000);

        vault.resume();

        assertEq(vault.feeTotal(), 0);
        assertEq(vault.fees(feeRecipient), 0);
    }
}
