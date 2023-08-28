// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAeraVaultV2.sol";
import "lib/forge-std/src/StdStorage.sol";
import "@openzeppelin/Create2.sol";
import {VaultParameters} from "src/v2/Types.sol";

contract DeploymentTest is TestBaseAeraVaultV2 {
    using stdStorage for StdStorage;

    address public weth = _WETH_ADDRESS;
    VaultParameters public parameters;

    function setUp() public override {
        super.setUp();

        assetRegistry = new AeraVaultAssetRegistry(
            address(this),
            Create2.computeAddress(
                bytes32(_ONE), keccak256(type(AeraVaultV2).creationCode)
            ),
            assetsInformation,
            numeraireId,
            feeToken
        );
    }

    function test_aeraVaultV2Deployment_fail_whenAssetRegistryIsZeroAddress()
        public
    {
        vm.expectRevert(ICustody.Aera__AssetRegistryIsZeroAddress.selector);
        _deployVault(
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
        _deployVault(
            address(this),
            address(1),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault"
        );
    }

    function test_aeraVaultV2Deployment_fail_whenRegisteredCustodyIsNotValid()
        public
    {
        assetRegistry = new AeraVaultAssetRegistry(
            address(this),
            Create2.computeAddress(
                bytes32(_ONE + 1), keccak256(type(AeraVaultV2).creationCode)
            ),
            assetsInformation,
            numeraireId,
            feeToken
        );

        vm.expectRevert(ICustody.Aera__AssetRegistryHasInvalidCustody.selector);
        _deployVault(
            address(this),
            address(assetRegistry),
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
        _deployVault(
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
        _deployVault(
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
        _deployVault(
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
        _deployVault(
            address(this),
            address(assetRegistry),
            _GUARDIAN,
            address(this),
            _MAX_FEE,
            "Test Vault"
        );
    }

    function test_aeraVaultV2Deployment_fail_whenOwnerIsZeroAddress() public {
        vm.expectRevert(ICustody.Aera__InitialOwnerIsZeroAddress.selector);
        _deployVault(
            address(0),
            address(assetRegistry),
            _GUARDIAN,
            _FEE_RECIPIENT,
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
        _deployVault(
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
        _deployVault(
            address(this),
            address(assetRegistry),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            ""
        );
    }

    function test_aeraVaultV2Deployment_fail_whenWETHIsZeroAddress() public {
        weth = address(0);

        vm.expectRevert(ICustody.Aera__WETHIsZeroAddress.selector);
        _deployVault(
            address(this),
            address(assetRegistry),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault"
        );
    }

    function test_aeraVaultV2Deployment_success() public {
        vm.expectEmit(true, true, true, true);
        emit SetAssetRegistry(address(assetRegistry));
        vm.expectEmit(true, true, true, true);
        emit SetGuardianAndFeeRecipient(_GUARDIAN, _FEE_RECIPIENT);

        vault = _deployVault(
            address(this),
            address(assetRegistry),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault"
        );

        assertTrue(vault.paused());
        assertEq(address(vault.assetRegistry()), address(assetRegistry));
        assertEq(vault.guardian(), _GUARDIAN);
        assertEq(vault.feeRecipient(), _FEE_RECIPIENT);
        assertEq(vault.fee(), _MAX_FEE);
        assertEq(vault.description(), "Test Vault");
        assertEq(vault.weth(), _WETH_ADDRESS);
        assertEq(assetRegistry.custody(), address(vault));

        _setInvalidOracle(nonNumeraireId);

        skip(1000);

        hooks = new AeraVaultHooks(
            address(this),
            address(vault),
            _MAX_DAILY_EXECUTION_LOSS,
            targetSighashAllowlist
        );

        vault.setHooks(address(hooks));

        assertEq(address(vault.hooks()), address(hooks));
        assertEq(vault.feeTotal(), 0);
    }

    function _deployVault(
        address owner,
        address assetRegistry,
        address guardian,
        address feeRecipient,
        uint256 fee,
        string memory description
    ) internal returns (AeraVaultV2 deployed) {
        parameters = VaultParameters({
            owner: owner,
            assetRegistry: assetRegistry,
            guardian: guardian,
            feeRecipient: feeRecipient,
            fee: fee,
            description: description
        });

        deployed = new AeraVaultV2{salt: bytes32(_ONE)}();

        delete parameters;
    }
}
