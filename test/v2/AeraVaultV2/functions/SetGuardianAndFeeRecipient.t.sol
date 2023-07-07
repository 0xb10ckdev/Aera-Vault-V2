// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";

contract SetGuardianAndFeeRecipientTest is TestBaseAeraVaultV2 {
    function test_setGuardianAndFeeRecipient_fail_whenCallerIsNotOwner()
        public
    {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        vault.setGuardianAndFeeRecipient(_USER, _FEE_RECIPIENT);
    }

    function test_setGuardianAndFeeRecipient_fail_whenFinalized() public {
        vault.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        vault.setGuardianAndFeeRecipient(_USER, _FEE_RECIPIENT);
    }

    function test_setGuardianAndFeeRecipient_fail_whenGuardianIsZeroAddress()
        public
    {
        vm.expectRevert(ICustody.Aera__GuardianIsZeroAddress.selector);

        vault.setGuardianAndFeeRecipient(address(0), _FEE_RECIPIENT);
    }

    function test_setGuardianAndFeeRecipient_fail_whenGuardianIsOwner()
        public
    {
        vm.expectRevert(ICustody.Aera__GuardianIsOwner.selector);

        vault.setGuardianAndFeeRecipient(address(this), _FEE_RECIPIENT);
    }

    function test_setGuardianAndFeeRecipient_fail_whenFeeRecipientIsZeroAddress(
    ) public {
        vm.expectRevert(ICustody.Aera__FeeRecipientIsZeroAddress.selector);

        vault.setGuardianAndFeeRecipient(_GUARDIAN, address(0));
    }

    function test_setGuardianAndFeeRecipient_fail_whenFeeRecipientIsOwner()
        public
    {
        vm.expectRevert(ICustody.Aera__FeeRecipientIsOwner.selector);

        vault.setGuardianAndFeeRecipient(_GUARDIAN, address(this));
    }

    function test_setGuardianAndFeeRecipient_success_whenOraclePriceIsInvalid()
        public
    {
        _setInvalidOracle(nonNumeraire);

        vm.expectEmit(true, true, true, true, address(vault));
        emit SetGuardianAndFeeRecipient(_USER, address(1));

        vault.setGuardianAndFeeRecipient(_USER, address(1));
    }

    function test_setGuardianAndFeeRecipient_success() public {
        vm.expectEmit(true, true, true, true, address(vault));
        emit SetGuardianAndFeeRecipient(_USER, address(1));

        vault.setGuardianAndFeeRecipient(_USER, address(1));

        assertEq(vault.guardian(), _USER);
        assertEq(vault.feeRecipient(), address(1));
    }
}
