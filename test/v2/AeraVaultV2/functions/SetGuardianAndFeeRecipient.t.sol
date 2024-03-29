// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAeraVaultV2.sol";

contract SetGuardianAndFeeRecipientTest is TestBaseAeraVaultV2 {
    function test_setGuardianAndFeeRecipient_fail_whenCallerIsNotOwner()
        public
    {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(_USER);
        vault.setGuardianAndFeeRecipient(_USER, _FEE_RECIPIENT);
    }

    function test_setGuardianAndFeeRecipient_fail_whenFinalized() public {
        vault.finalize();

        vm.expectRevert(IVault.Aera__VaultIsFinalized.selector);

        vault.setGuardianAndFeeRecipient(_USER, _FEE_RECIPIENT);
    }

    function test_setGuardianAndFeeRecipient_fail_whenGuardianIsZeroAddress()
        public
    {
        vm.expectRevert(IVault.Aera__GuardianIsZeroAddress.selector);

        vault.setGuardianAndFeeRecipient(address(0), _FEE_RECIPIENT);
    }

    function test_setGuardianAndFeeRecipient_fail_whenGuardianIsOwner()
        public
    {
        vm.expectRevert(IVault.Aera__GuardianIsOwner.selector);

        vault.setGuardianAndFeeRecipient(address(this), _FEE_RECIPIENT);
    }

    function test_setGuardianAndFeeRecipient_fail_whenFeeRecipientIsZeroAddress(
    ) public {
        vm.expectRevert(IVault.Aera__FeeRecipientIsZeroAddress.selector);

        vault.setGuardianAndFeeRecipient(_GUARDIAN, address(0));
    }

    function test_setGuardianAndFeeRecipient_fail_whenFeeRecipientIsOwner()
        public
    {
        vm.expectRevert(IVault.Aera__FeeRecipientIsOwner.selector);

        vault.setGuardianAndFeeRecipient(_GUARDIAN, address(this));
    }

    function test_setGuardianAndFeeRecipient_success_whenOraclePriceIsInvalid()
        public
    {
        _setInvalidOracle(nonNumeraireId);

        uint256 lastFeeCheckpoint = vault.lastFeeCheckpoint();
        uint256 lastValue = vault.lastValue();
        uint256 feeTotal = vault.feeTotal();

        skip(1000);

        vm.expectEmit(true, true, true, true, address(vault));
        emit SpotPricesReverted(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__OraclePriceIsInvalid.selector,
                assetsInformation[nonNumeraireId],
                -1
            )
        );

        vm.expectEmit(true, true, true, true, address(vault));
        emit NoFeesReserved(lastFeeCheckpoint, lastValue, feeTotal);

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

    function test_setGuardianAndFeeRecipient_increases_fees() public {
        address feeRecipient = address(1);
        vault.setGuardianAndFeeRecipient(_USER, feeRecipient);

        assertEq(vault.feeTotal(), 0);
        assertEq(vault.fees(feeRecipient), 0);

        vm.warp(block.timestamp + 1000);

        test_setGuardianAndFeeRecipient_success();

        assertEq(vault.feeTotal(), 499999);
        assertEq(vault.fees(feeRecipient), 499999);
    }
}
