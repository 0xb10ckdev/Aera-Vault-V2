// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "src/v2/AeraVaultAssetRegistry.sol";
import "src/v2/AeraVaultHooks.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/AeraV2Factory.sol";
import "src/v2/interfaces/IVaultEvents.sol";
import {TestBaseVault} from "test/v2/utils/TestBase/TestBaseVault.sol";

contract AeraV2FactoryTest is TestBaseVault, IVaultEvents {
    function setUp() public override {
        super.setUp();

        if (_testWithDeployedContracts()) {
            (, address deployedFactory,,) = _loadDeployedAddresses();

            factory = AeraV2Factory(deployedFactory);

            _updateOwnership();
            _loadParameters();
        }
    }

    function test_aeraV2FactoryDeployment_fail_whenWrappedNativeTokenIsZeroAddress(
    ) public {
        vm.expectRevert(
            AeraV2Factory.Aera__WrappedNativeTokenIsZeroAddress.selector
        );
        new AeraV2Factory(address(0));
    }

    function test_aeraV2FactoryDeployment_fail_whenWrappedNativeTokenIsNotContract(
    ) public {
        vm.expectRevert(AeraV2Factory.Aera__InvalidWrappedNativeToken.selector);
        new AeraV2Factory(address(1));
    }

    function test_aeraV2FactoryDeployment_fail_whenWrappedNativeTokenIsNotERC20(
    ) public {
        vm.expectRevert(AeraV2Factory.Aera__InvalidWrappedNativeToken.selector);
        new AeraV2Factory(address(vault));
    }

    function test_createAeraV2Contracts_fail_whenCallerIsNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(_USER);
        factory.create(
            bytes32(_ONE),
            address(this),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault",
            assetRegistryParameters,
            hooksParameters
        );
    }

    function test_createAeraV2Contracts_fail_whenGuardianIsZeroAddress()
        public
    {
        vm.expectRevert(IVault.Aera__GuardianIsZeroAddress.selector);

        factory.create(
            bytes32(_ONE),
            address(this),
            address(0),
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault",
            assetRegistryParameters,
            hooksParameters
        );
    }

    function test_createAeraV2Contracts_fail_whenGuardianIsOwner() public {
        vm.expectRevert(IVault.Aera__GuardianIsOwner.selector);
        factory.create(
            bytes32(_ONE),
            address(factory),
            address(factory),
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault",
            assetRegistryParameters,
            hooksParameters
        );
    }

    function test_createAeraV2Contracts_fail_whenOwnerIsZeroAddress() public {
        vm.expectRevert(IVault.Aera__InitialOwnerIsZeroAddress.selector);
        factory.create(
            bytes32(_ONE),
            address(0),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault",
            assetRegistryParameters,
            hooksParameters
        );
    }

    function test_createAeraV2Contracts_fail_whenFeeRecipientIsZeroAddress()
        public
    {
        vm.expectRevert(IVault.Aera__FeeRecipientIsZeroAddress.selector);
        factory.create(
            bytes32(_ONE),
            address(this),
            _GUARDIAN,
            address(0),
            _MAX_FEE,
            "Test Vault",
            assetRegistryParameters,
            hooksParameters
        );
    }

    function test_createAeraV2Contracts_fail_whenFeeRecipientIsOwner()
        public
    {
        vm.expectRevert(IVault.Aera__FeeRecipientIsOwner.selector);
        factory.create(
            bytes32(_ONE),
            address(factory),
            _GUARDIAN,
            address(factory),
            _MAX_FEE,
            "Test Vault",
            assetRegistryParameters,
            hooksParameters
        );
    }

    function test_createAeraV2Contracts_fail_whenFeeIsAboveMax() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IVault.Aera__FeeIsAboveMax.selector, _MAX_FEE + 1, _MAX_FEE
            )
        );
        factory.create(
            bytes32(_ONE),
            address(this),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE + 1,
            "Test Vault",
            assetRegistryParameters,
            hooksParameters
        );
    }

    function test_createAeraV2Contracts_fail_whenDescriptionIsEmpty() public {
        vm.expectRevert(AeraV2Factory.Aera__DescriptionIsEmpty.selector);
        factory.create(
            bytes32(_ONE),
            address(this),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            "",
            assetRegistryParameters,
            hooksParameters
        );
    }

    function test_createAeraV2Contracts_success() public {
        address predict = factory.computeVaultAddress(
            bytes32(_ONE),
            address(this),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault"
        );

        (
            address deployedVault,
            address deployedAssetRegistry,
            address deployedHooks
        ) = factory.create(
            bytes32(_ONE),
            address(this),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault",
            assetRegistryParameters,
            hooksParameters
        );

        vault = AeraVaultV2(payable(deployedVault));
        assetRegistry = AeraVaultAssetRegistry(deployedAssetRegistry);
        hooks = AeraVaultHooks(deployedHooks);

        assertEq(address(vault), predict);
        assertEq(vault.owner(), address(this));
        assertEq(address(vault.assetRegistry()), address(assetRegistry));
        assertEq(vault.guardian(), _GUARDIAN);
        assertEq(vault.feeRecipient(), _FEE_RECIPIENT);
        assertEq(vault.fee(), _MAX_FEE);

        assertEq(assetRegistry.owner(), assetRegistryParameters.owner);
        assertEq(assetRegistry.vault(), address(vault));
        assertEq(
            assetRegistry.numeraireId(), assetRegistryParameters.numeraireId
        );
        assertEq(
            address(assetRegistry.feeToken()),
            address(assetRegistryParameters.feeToken)
        );

        assertEq(hooks.owner(), hooksParameters.owner);
        assertEq(address(hooks.vault()), address(vault));
        assertEq(
            hooks.maxDailyExecutionLoss(),
            hooksParameters.maxDailyExecutionLoss
        );
        assertEq(hooks.currentDay(), block.timestamp / 1 days);
        assertEq(hooks.cumulativeDailyMultiplier(), _ONE);
    }
}
