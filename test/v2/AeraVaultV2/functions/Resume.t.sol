// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "lib/forge-std/src/StdStorage.sol";
import "../TestBaseAeraVaultV2.sol";

contract ResumeTest is TestBaseAeraVaultV2 {
    using stdStorage for StdStorage;

    event Unpaused(address);

    function test_resume_fail_whenCallerIsNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(_USER);
        vault.resume();
    }

    function test_resume_fail_whenHooksIsNotSet() public {
        vault.pause();
        vm.store(
            address(vault),
            bytes32(stdstore.target(address(vault)).sig("hooks()").find()),
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
        vm.expectRevert("Pausable: not paused");

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
