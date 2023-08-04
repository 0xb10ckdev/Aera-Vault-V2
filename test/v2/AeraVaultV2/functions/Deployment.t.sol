// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";

contract DeploymentTest is TestBaseAeraVaultV2 {
    function test_aeraVaultV2Deployment_fail_whenAssetRegistryIsZeroAddress()
        public
    {
        vm.expectRevert(ICustody.Aera__AssetRegistryIsZeroAddress.selector);
        new AeraVaultV2(
            address(this),
            address(0),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault"
        );
    }

    function test_aeraVaultV2Deployment_fail_whenAssetRegistryIsNotValid()
        public
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__AssetRegistryIsNotValid.selector, address(1)
            )
        );

        new AeraVaultV2(
            address(this),
            address(1),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault"
        );
    }

    function test_aeraVaultV2Deployment_fail_whenGuardianIsZeroAddress()
        public
    {
        vm.expectRevert(ICustody.Aera__GuardianIsZeroAddress.selector);
        new AeraVaultV2(
            address(this),
            address(assetRegistry),
            address(0),
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault"
        );
    }

    function test_aeraVaultV2Deployment_fail_whenGuardianIsOwner() public {
        vm.expectRevert(ICustody.Aera__GuardianIsOwner.selector);
        new AeraVaultV2(
            address(this),
            address(assetRegistry),
            address(this),
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault"
        );
    }

    function test_aeraVaultV2Deployment_fail_whenFeeRecipientIsZeroAddress()
        public
    {
        vm.expectRevert(ICustody.Aera__FeeRecipientIsZeroAddress.selector);
        new AeraVaultV2(
            address(this),
            address(assetRegistry),
            _GUARDIAN,
            address(0),
            _MAX_FEE,
            "Test Vault"
        );
    }

    function test_aeraVaultV2Deployment_fail_whenFeeRecipientIsOwner()
        public
    {
        vm.expectRevert(ICustody.Aera__FeeRecipientIsOwner.selector);
        new AeraVaultV2(
            address(this),
            address(assetRegistry),
            _GUARDIAN,
            address(this),
            _MAX_FEE,
            "Test Vault"
        );
    }

    function test_aeraVaultV2Deployment_fail_whenFeeIsAboveMax() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__FeeIsAboveMax.selector, _MAX_FEE + 1, _MAX_FEE
            )
        );
        new AeraVaultV2(
            address(this),
            address(assetRegistry),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE + 1,
            "Test Vault"
        );
    }

    function test_aeraVaultV2Deployment_fail_whenDescriptionIsEmpty() public {
        vm.expectRevert(ICustody.Aera__DescriptionIsEmpty.selector);
        new AeraVaultV2(
            address(this),
            address(assetRegistry),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            ""
        );
    }

    function test_aeraVaultV2Deployment_success() public {
        vm.expectEmit(true, true, true, true);
        emit SetAssetRegistry(address(assetRegistry));
        vm.expectEmit(true, true, true, true);
        emit SetGuardianAndFeeRecipient(_GUARDIAN, _FEE_RECIPIENT);

        vault = new AeraVaultV2(
            address(this),
            address(assetRegistry),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault"
        );

        assertEq(address(vault.assetRegistry()), address(assetRegistry));
        assertEq(vault.guardian(), _GUARDIAN);
        assertEq(vault.feeRecipient(), _FEE_RECIPIENT);
        assertEq(vault.fee(), _MAX_FEE);
        assertEq(vault.description(), "Test Vault");
    }
}
