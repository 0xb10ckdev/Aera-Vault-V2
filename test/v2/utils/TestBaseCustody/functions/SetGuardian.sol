// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseCustody.sol";

abstract contract BaseSetGuardianTest is TestBaseCustody {
    function test_setGuardian_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        custody.setGuardian(_USER);
    }

    function test_setGuardian_fail_whenFinalized() public {
        custody.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        custody.setGuardian(_USER);
    }

    function test_setGuardian_fail_whenGuardianIsZeroAddress() public {
        vm.expectRevert(ICustody.Aera__GuardianIsZeroAddress.selector);

        custody.setGuardian(address(0));
    }

    function test_setGuardian_fail_whenGuardianIsOwner() public {
        vm.expectRevert(ICustody.Aera__GuardianIsOwner.selector);

        custody.setGuardian(address(this));
    }

    function test_setGuardian_success() public virtual {
        vm.expectEmit(true, true, true, true, address(custody));
        emit SetGuardian(_USER);

        custody.setGuardian(_USER);

        assertEq(custody.guardian(), _USER);
    }
}
