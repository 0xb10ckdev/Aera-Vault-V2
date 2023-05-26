// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";

contract SetGuardianTest is TestBaseAeraVaultV2 {
    function test_setGuardian_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        vault.setGuardian(_USER);
    }

    function test_setGuardian_fail_whenFinalized() public {
        vault.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        vault.setGuardian(_USER);
    }

    function test_setGuardian_fail_whenGuardianIsZeroAddress() public {
        vm.expectRevert(ICustody.Aera__GuardianIsZeroAddress.selector);

        vault.setGuardian(address(0));
    }

    function test_setGuardian_fail_whenGuardianIsOwner() public {
        vm.expectRevert(ICustody.Aera__GuardianIsOwner.selector);

        vault.setGuardian(address(this));
    }

    function test_setGuardian_success() public virtual {
        vm.expectEmit(true, true, true, true, address(vault));
        emit SetGuardian(_USER);

        vault.setGuardian(_USER);

        assertEq(vault.guardian(), _USER);
    }
}
