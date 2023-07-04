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

    function test_resume_success() public virtual {
        vault.pause();

        vm.expectEmit(true, true, true, true, address(vault));
        emit Unpaused(address(this));

        vault.resume();
    }
}
