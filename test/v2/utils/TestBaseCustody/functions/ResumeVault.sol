// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseCustody.sol";

abstract contract BaseResumeVaultTest is TestBaseCustody {
    function test_resumeVault_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        custody.resumeVault();
    }

    function test_resumeVault_fail_whenFinalized() public {
        custody.pauseVault();
        custody.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        custody.resumeVault();
    }

    function test_resumeVault_fail_whenVaultIsNotPaused() public {
        vm.expectRevert(ICustody.Aera__VaultIsNotPaused.selector);

        custody.resumeVault();
    }

    function test_resumeVault_success() public virtual {
        custody.pauseVault();

        vm.expectEmit(true, true, true, true, address(custody));
        emit ResumeVault();

        custody.resumeVault();
    }
}
