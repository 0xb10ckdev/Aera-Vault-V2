// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAeraVaultV2.sol";
import "lib/forge-std/src/StdStorage.sol";
import "@openzeppelin/Create2.sol";
import {VaultParameters} from "src/v2/Types.sol";

contract DeploymentTest is TestBaseAeraVaultV2 {
    using stdStorage for StdStorage;

    address public wrappedNativeToken = _WETH_ADDRESS;
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
            feeToken,
            AggregatorV2V3Interface(address(0))
        );

        hooks = new AeraVaultHooks(
            address(this),
            Create2.computeAddress(
                bytes32(_ONE), keccak256(type(AeraVaultV2).creationCode)
            ),
            _MAX_DAILY_EXECUTION_LOSS,
            targetSighashAllowlist
        );
    }

    function test_aeraVaultV2Deployment_fail_whenAssetRegistryIsZeroAddress()
        public
    {
        vm.expectRevert(IVault.Aera__AssetRegistryIsZeroAddress.selector);
        _deployVault(
            address(this),
            address(0),
            address(hooks),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE
        );
    }

    function test_aeraVaultV2Deployment_fail_whenAssetRegistryIsNotValid()
        public
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                IVault.Aera__AssetRegistryIsNotValid.selector, address(1)
            )
        );
        _deployVault(
            address(this),
            address(1),
            address(hooks),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE
        );
    }

    function test_aeraVaultV2Deployment_fail_whenRegisteredVaultIsNotValid()
        public
    {
        assetRegistry = new AeraVaultAssetRegistry(
            address(this),
            Create2.computeAddress(
                bytes32(_ONE + 1), keccak256(type(AeraVaultV2).creationCode)
            ),
            assetsInformation,
            numeraireId,
            feeToken,
            AggregatorV2V3Interface(address(0))
        );

        vm.expectRevert(IVault.Aera__AssetRegistryHasInvalidVault.selector);
        _deployVault(
            address(this),
            address(assetRegistry),
            address(hooks),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE
        );
    }

    function test_aeraVaultV2Deployment_fail_whenGuardianIsZeroAddress()
        public
    {
        vm.expectRevert(IVault.Aera__GuardianIsZeroAddress.selector);
        _deployVault(
            address(this),
            address(assetRegistry),
            address(hooks),
            address(0),
            _FEE_RECIPIENT,
            _MAX_FEE
        );
    }

    function test_aeraVaultV2Deployment_fail_whenGuardianIsOwner() public {
        vm.expectRevert(IVault.Aera__GuardianIsOwner.selector);
        _deployVault(
            address(this),
            address(assetRegistry),
            address(hooks),
            address(this),
            _FEE_RECIPIENT,
            _MAX_FEE
        );
    }

    function test_aeraVaultV2Deployment_fail_whenFeeRecipientIsZeroAddress()
        public
    {
        vm.expectRevert(IVault.Aera__FeeRecipientIsZeroAddress.selector);
        _deployVault(
            address(this),
            address(assetRegistry),
            address(hooks),
            _GUARDIAN,
            address(0),
            _MAX_FEE
        );
    }

    function test_aeraVaultV2Deployment_fail_whenFeeRecipientIsOwner()
        public
    {
        vm.expectRevert(IVault.Aera__FeeRecipientIsOwner.selector);
        _deployVault(
            address(this),
            address(assetRegistry),
            address(hooks),
            _GUARDIAN,
            address(this),
            _MAX_FEE
        );
    }

    function test_aeraVaultV2Deployment_fail_whenOwnerIsZeroAddress() public {
        vm.expectRevert(IVault.Aera__InitialOwnerIsZeroAddress.selector);
        _deployVault(
            address(0),
            address(assetRegistry),
            address(hooks),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE
        );
    }

    function test_aeraVaultV2Deployment_fail_whenFeeIsAboveMax() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IVault.Aera__FeeIsAboveMax.selector, _MAX_FEE + 1, _MAX_FEE
            )
        );
        _deployVault(
            address(this),
            address(assetRegistry),
            address(hooks),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE + 1
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
            address(hooks),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE
        );

        assertTrue(vault.paused());
        assertEq(address(vault.assetRegistry()), address(assetRegistry));
        assertEq(vault.guardian(), _GUARDIAN);
        assertEq(vault.feeRecipient(), _FEE_RECIPIENT);
        assertEq(vault.fee(), _MAX_FEE);
        assertEq(vault.wrappedNativeToken(), _WETH_ADDRESS);
        assertEq(assetRegistry.vault(), address(vault));

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
        address hooks,
        address guardian,
        address feeRecipient,
        uint256 fee
    ) internal returns (AeraVaultV2 deployed) {
        parameters = VaultParameters(
            owner, assetRegistry, hooks, guardian, feeRecipient, fee
        );

        deployed = new AeraVaultV2{salt: bytes32(_ONE)}();

        delete parameters;
    }
}
