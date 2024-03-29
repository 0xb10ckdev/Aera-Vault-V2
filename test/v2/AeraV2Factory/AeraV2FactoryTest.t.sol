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
        _deployAeraV2Contracts();
    }

    function test_createAeraV2Contracts_fail_whenGuardianIsZeroAddress()
        public
    {
        vaultParameters.guardian = address(0);

        vm.expectRevert(IVault.Aera__GuardianIsZeroAddress.selector);
        _deployAeraV2Contracts();
    }

    function test_createAeraV2Contracts_fail_whenGuardianIsOwner() public {
        vaultParameters.guardian = address(this);

        vm.expectRevert(AeraV2Factory.Aera__GuardianIsAssetRegistryOwner.selector);
        _deployAeraV2Contracts();
    }

    function test_createAeraV2Contracts_fail_whenOwnerIsZeroAddress() public {
        vaultParameters.owner = address(0);

        vm.expectRevert(IVault.Aera__InitialOwnerIsZeroAddress.selector);
        _deployAeraV2Contracts();
    }

    function test_createAeraV2Contracts_fail_whenFeeRecipientIsZeroAddress()
        public
    {
        vaultParameters.feeRecipient = address(0);

        vm.expectRevert(IVault.Aera__FeeRecipientIsZeroAddress.selector);
        _deployAeraV2Contracts();
    }

    function test_createAeraV2Contracts_fail_whenFeeRecipientIsOwner()
        public
    {
        vaultParameters.feeRecipient = address(this);

        vm.expectRevert(IVault.Aera__FeeRecipientIsOwner.selector);
        _deployAeraV2Contracts();
    }

    function test_createAeraV2Contracts_fail_whenFeeIsAboveMax() public {
        vaultParameters.fee = _MAX_FEE + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                IVault.Aera__FeeIsAboveMax.selector, _MAX_FEE + 1, _MAX_FEE
            )
        );
        _deployAeraV2Contracts();
    }

    function test_createAeraV2Contracts_fail_whenDescriptionIsEmpty() public {
        vm.expectRevert(AeraV2Factory.Aera__DescriptionIsEmpty.selector);
        factory.create(
            bytes32(_ONE),
            "",
            vaultParameters,
            assetRegistryParameters,
            hooksParameters
        );
    }

    function test_createAeraV2Contracts_success() public {
        address predict = factory.computeVaultAddress(
            bytes32(_ONE), "Test Vault", vaultParameters
        );

        (
            address deployedVault,
            address deployedAssetRegistry,
            address deployedHooks
        ) = factory.create(
            bytes32(_ONE),
            "Test Vault",
            vaultParameters,
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
            address(assetRegistry.numeraireToken()),
            address(assetRegistryParameters.numeraireToken)
        );
        assertEq(
            address(assetRegistry.feeToken()),
            address(assetRegistryParameters.feeToken)
        );

        assertEq(hooks.owner(), hooksParameters.owner);
        assertEq(address(hooks.vault()), address(vault));
        assertEq(
            hooks.minDailyValue(),
            hooksParameters.minDailyValue
        );
        assertEq(hooks.currentDay(), block.timestamp / 1 days);
        assertEq(hooks.cumulativeDailyMultiplier(), _ONE);
    }
}
