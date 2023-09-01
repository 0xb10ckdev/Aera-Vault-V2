// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "src/v2/AeraVaultAssetRegistry.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/AeraVaultV2Factory.sol";
import "src/v2/interfaces/IVaultEvents.sol";
import {TestBaseVault} from "test/v2/utils/TestBase/TestBaseVault.sol";

contract AeraVaultV2FactoryTest is TestBaseVault, IVaultEvents {
    function setUp() public override {
        super.setUp();

        if (_testWithDeployedContracts()) {
            (, address deployedFactory,,) = _loadDeployedAddresses();

            factory = AeraVaultV2Factory(deployedFactory);

            _updateOwnership();
            _loadParameters();
        }

        assetRegistry = new AeraVaultAssetRegistry(
            address(this),
            factory.computeVaultAddress(bytes32(_ONE)),
            assetsInformation,
            numeraireId,
            feeToken
        );
    }

    function test_aeraVaultV2FactoryDeployment_fail_whenWrappedNativeTokenIsZeroAddress(
    ) public {
        vm.expectRevert(
            AeraVaultV2Factory.Aera__WrappedNativeTokenIsZeroAddress.selector
        );
        new AeraVaultV2Factory(address(0));
    }

    function test_createAeraVaultV2_fail_whenCallerIsNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(_USER);
        factory.create(
            bytes32(_ONE),
            address(this),
            address(0),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault"
        );
    }

    function test_createAeraVaultV2_fail_whenAssetRegistryIsZeroAddress()
        public
    {
        vm.expectRevert(IVault.Aera__AssetRegistryIsZeroAddress.selector);
        factory.create(
            bytes32(_ONE),
            address(this),
            address(0),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault"
        );
    }

    function test_createAeraVaultV2_fail_whenAssetRegistryIsNotValid()
        public
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                IVault.Aera__AssetRegistryIsNotValid.selector, address(1)
            )
        );
        factory.create(
            bytes32(_ONE),
            address(this),
            address(1),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault"
        );
    }

    function test_createAeraVaultV2_fail_whenRegisteredVaultIsNotValid()
        public
    {
        assetRegistry = new AeraVaultAssetRegistry(
            address(this),
            factory.computeVaultAddress(bytes32(_ONE + 1)),
            assetsInformation,
            numeraireId,
            feeToken
        );

        vm.expectRevert(IVault.Aera__AssetRegistryHasInvalidVault.selector);
        factory.create(
            bytes32(_ONE),
            address(this),
            address(assetRegistry),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault"
        );
    }

    function test_createAeraVaultV2_fail_whenGuardianIsZeroAddress() public {
        vm.expectRevert(IVault.Aera__GuardianIsZeroAddress.selector);
        factory.create(
            bytes32(_ONE),
            address(this),
            address(assetRegistry),
            address(0),
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault"
        );
    }

    function test_createAeraVaultV2_fail_whenGuardianIsFactory() public {
        vm.expectRevert(IVault.Aera__GuardianIsOwner.selector);
        factory.create(
            bytes32(_ONE),
            address(this),
            address(assetRegistry),
            address(factory),
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault"
        );
    }

    function test_createAeraVaultV2_fail_whenOwnerIsZeroAddress() public {
        vm.expectRevert(IVault.Aera__InitialOwnerIsZeroAddress.selector);
        factory.create(
            bytes32(_ONE),
            address(0),
            address(assetRegistry),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault"
        );
    }

    function test_createAeraVaultV2_fail_whenFeeRecipientIsZeroAddress()
        public
    {
        vm.expectRevert(IVault.Aera__FeeRecipientIsZeroAddress.selector);
        factory.create(
            bytes32(_ONE),
            address(this),
            address(assetRegistry),
            _GUARDIAN,
            address(0),
            _MAX_FEE,
            "Test Vault"
        );
    }

    function test_createAeraVaultV2_fail_whenFeeRecipientIsFactory() public {
        vm.expectRevert(IVault.Aera__FeeRecipientIsOwner.selector);
        factory.create(
            bytes32(_ONE),
            address(this),
            address(assetRegistry),
            _GUARDIAN,
            address(factory),
            _MAX_FEE,
            "Test Vault"
        );
    }

    function test_createAeraVaultV2_fail_whenFeeIsAboveMax() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IVault.Aera__FeeIsAboveMax.selector, _MAX_FEE + 1, _MAX_FEE
            )
        );
        factory.create(
            bytes32(_ONE),
            address(this),
            address(assetRegistry),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE + 1,
            "Test Vault"
        );
    }

    function test_createAeraVaultV2_fail_whenDescriptionIsEmpty() public {
        vm.expectRevert(AeraVaultV2Factory.Aera__DescriptionIsEmpty.selector);
        factory.create(
            bytes32(_ONE),
            address(this),
            address(assetRegistry),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            ""
        );
    }

    function test_createAeraVaultV2_success() public {
        address predict = factory.computeVaultAddress(bytes32(_ONE));

        vm.expectEmit(true, true, true, true);
        emit SetAssetRegistry(address(assetRegistry));
        vm.expectEmit(true, true, true, true);
        emit SetGuardianAndFeeRecipient(_GUARDIAN, _FEE_RECIPIENT);

        AeraVaultV2 vault = AeraVaultV2(
            payable(
                factory.create(
                    bytes32(_ONE),
                    address(this),
                    address(assetRegistry),
                    _GUARDIAN,
                    _FEE_RECIPIENT,
                    _MAX_FEE,
                    "Test Vault"
                )
            )
        );

        assertEq(address(vault), predict);
        assertEq(address(vault.assetRegistry()), address(assetRegistry));
        assertEq(vault.guardian(), _GUARDIAN);
        assertEq(vault.feeRecipient(), _FEE_RECIPIENT);
        assertEq(vault.fee(), _MAX_FEE);
    }
}
