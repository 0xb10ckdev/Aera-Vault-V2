// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/Create2.sol";
import "@openzeppelin/Ownable2Step.sol";
import "./AeraVaultAssetRegistry.sol";
import "./AeraVaultHooks.sol";
import "./AeraVaultV2.sol";
import "./interfaces/IAeraVaultV2Factory.sol";
import {VaultParameters} from "./Types.sol";

/// @title AeraVaultV2Factory
/// @notice Used to create new vaults and deploy arbitrary non-payable contracts with create2.
/// @dev Only one instance of the factory will be required per chain.
contract AeraVaultV2Factory is IAeraVaultV2Factory, Ownable2Step {
    /// @notice The address of wrapped native token.
    address public immutable wrappedNativeToken;

    /// STORAGE ///

    /// @notice Vault parameters for vault deployment.
    VaultParameters public override parameters;

    /// EVENTS ///

    /// @notice Emitted when the vault is created.
    /// @param vault Vault address.
    /// @param assetRegistry Asset registry address.
    /// @param guardian Guardian address.
    /// @param feeRecipient Fee recipient address.
    /// @param fee Fee accrued per second, denoted in 18 decimal fixed point format.
    /// @param description Vault description.
    /// @param wrappedNativeToken The address of wrapped native token.
    event VaultCreated(
        address indexed vault,
        address assetRegistry,
        address indexed guardian,
        address indexed feeRecipient,
        uint256 fee,
        string description,
        address wrappedNativeToken
    );

    /// ERRORS ///

    error Aera__DescriptionIsEmpty();
    error Aera__WrappedNativeTokenIsZeroAddress();

    /// FUNCTIONS ///

    /// @notice Initialize the factory contract.
    /// @param wrappedNativeToken_ The address of wrapped native token.
    constructor(address wrappedNativeToken_) {
        if (wrappedNativeToken_ == address(0)) {
            revert Aera__WrappedNativeTokenIsZeroAddress();
        }

        wrappedNativeToken = wrappedNativeToken_;
    }

    /// @inheritdoc IAeraVaultV2Factory
    function create(
        bytes32 salt,
        address owner,
        address guardian,
        address feeRecipient,
        uint256 fee,
        string calldata description,
        AssetRegistryParameters memory assetRegistryParameters,
        HooksParameters memory hooksParameters
    ) external override onlyOwner returns (address deployedVault) {
        address deployedAssetRegistry = _deployAssetRegistry(
            salt, _computeVaultAddress(salt), assetRegistryParameters
        );

        deployedVault = _deployVault(
            salt,
            owner,
            deployedAssetRegistry,
            guardian,
            feeRecipient,
            fee,
            description
        );

        address deployedHooks =
            _deployHooks(salt, deployedVault, hooksParameters);

        AeraVaultV2(payable(deployedVault)).setHooks(deployedHooks);
    }

    /// @inheritdoc IAeraVaultV2Factory
    function computeVaultAddress(bytes32 salt)
        external
        view
        override
        returns (address)
    {
        return _computeVaultAddress(salt);
    }

    /// @inheritdoc IAeraVaultV2Factory
    function deploy(
        bytes32 salt,
        bytes calldata code
    ) external override onlyOwner {
        // Amount is 0 as the asset registry and hooks contracts are not payable.
        Create2.deploy(0, salt, code);
    }

    /// @inheritdoc IAeraVaultV2Factory
    function computeAddress(
        bytes32 salt,
        bytes calldata code
    ) external view override returns (address) {
        return Create2.computeAddress(salt, keccak256(code));
    }

    /// INTERNAL FUNCTIONS ///

    /// @notice Deploy asset registry.
    /// @param salt The salt value to deploy asset registry.
    /// @param vault Vault address.
    /// @param assetRegistryParameters Struct details for asset registry deployment.
    /// @return deployed The address of deployed asset registry.
    function _deployAssetRegistry(
        bytes32 salt,
        address vault,
        AssetRegistryParameters memory assetRegistryParameters
    ) internal returns (address deployed) {
        deployed = address(
            new AeraVaultAssetRegistry{salt: salt}(
                assetRegistryParameters.owner,
                vault,
                assetRegistryParameters.assets,
                assetRegistryParameters.numeraireId,
                assetRegistryParameters.feeToken
            )
        );
    }

    /// @notice Deploy V2 vault.
    /// @param salt The salt value to create vault.
    /// @param owner Initial owner address.
    /// @param assetRegistry Asset registry address.
    /// @param guardian Guardian address.
    /// @param feeRecipient Fee recipient address.
    /// @param fee Fee accrued per second, denoted in 18 decimal fixed point format.
    /// @param description Vault description.
    /// @return deployed The address of deployed vault.
    function _deployVault(
        bytes32 salt,
        address owner,
        address assetRegistry,
        address guardian,
        address feeRecipient,
        uint256 fee,
        string calldata description
    ) internal returns (address deployed) {
        parameters =
            VaultParameters(owner, assetRegistry, guardian, feeRecipient, fee);

        // Requirements, Effects and Interactions: deploy vault with create2.
        deployed = address(new AeraVaultV2{salt: salt}());

        delete parameters;

        // Log vault creation.
        emit VaultCreated(
            deployed,
            assetRegistry,
            guardian,
            feeRecipient,
            fee,
            description,
            wrappedNativeToken
        );
    }

    /// @notice Deploy asset registry.
    /// @param salt The salt value to deploy hooks.
    /// @param vault Vault address.
    /// @param hooksParameters Struct details for hooks deployment.
    /// @return deployed The address of deployed hooks.
    function _deployHooks(
        bytes32 salt,
        address vault,
        HooksParameters memory hooksParameters
    ) internal returns (address deployed) {
        deployed = address(
            new AeraVaultHooks{salt: salt}(
                hooksParameters.owner,
                vault,
                hooksParameters.maxDailyExecutionLoss,
                hooksParameters.targetSighashAllowlist
            )
        );
    }

    /// @notice Calculate deployment address of V2 vault.
    /// @param salt The salt value to create vault.
    /// @return Calculated deployment address.
    function _computeVaultAddress(bytes32 salt)
        internal
        view
        returns (address)
    {
        return Create2.computeAddress(
            salt, keccak256(type(AeraVaultV2).creationCode)
        );
    }
}
