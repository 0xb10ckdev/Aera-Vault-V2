// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";
import {IOracleMock} from "test/utils/OracleMock.sol";

contract SetGuardianTest is TestBaseAeraVaultV2 {
    function test_setGuardian_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        vault.setGuardian(_USER, _FEE_RECIPIENT);
    }

    function test_setGuardian_fail_whenFinalized() public {
        vault.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        vault.setGuardian(_USER, _FEE_RECIPIENT);
    }

    function test_setGuardian_fail_whenGuardianIsZeroAddress() public {
        vm.expectRevert(ICustody.Aera__GuardianIsZeroAddress.selector);

        vault.setGuardian(address(0), _FEE_RECIPIENT);
    }

    function test_setGuardian_fail_whenGuardianIsOwner() public {
        vm.expectRevert(ICustody.Aera__GuardianIsOwner.selector);

        vault.setGuardian(address(this), _FEE_RECIPIENT);
    }

    function test_setGuardian_fail_whenFeeRecipientIsZeroAddress() public {
        vm.expectRevert(ICustody.Aera__FeeRecipientIsZeroAddress.selector);

        vault.setGuardian(_GUARDIAN, address(0));
    }

    function test_setGuardian_fail_whenFeeRecipientIsOwner() public {
        vm.expectRevert(ICustody.Aera__FeeRecipientIsOwner.selector);

        vault.setGuardian(_GUARDIAN, address(this));
    }

    function test_setGuardian_success_whenOraclePriceIsInvalid()
        public
        virtual
    {
        IOracleMock(address(assetsInformation[nonNumeraire].oracle))
            .setLatestAnswer(-1);

        vm.expectEmit(true, true, true, true, address(vault));
        emit SetGuardian(_USER, address(1));

        vault.setGuardian(_USER, address(1));
    }

    function test_setGuardian_success() public virtual {
        vm.expectEmit(true, true, true, true, address(vault));
        emit SetGuardian(_USER, address(1));

        vault.setGuardian(_USER, address(1));

        assertEq(vault.guardian(), _USER);
        assertEq(vault.feeRecipient(), address(1));
    }
}
