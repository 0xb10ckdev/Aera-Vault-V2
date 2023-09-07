// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/Create2.sol";
import "@openzeppelin/Ownable2Step.sol";
import "@openzeppelin/IERC20.sol";
import "./AeraVaultV2.sol";
import "./interfaces/IAeraV2Factory.sol";
import "./interfaces/IAeraVaultAssetRegistryFactory.sol";
import "./interfaces/IAeraVaultHooksFactory.sol";
import {VaultParameters} from "./Types.sol";

/// @title AeraV2Factory
/// @notice Used to create new vaults and deploy arbitrary non-payable contracts with create2.
/// @dev Only one instance of the factory will be required per chain.
contract AeraV2Factory is IAeraV2Factory, Ownable2Step {
    /// @notice The address of wrapped native token.
    address public immutable wrappedNativeToken;

    /// STORAGE ///

    /// @notice Vault parameters for vault deployment.
    VaultParameters public override parameters;

    /// EVENTS ///

    /// @notice Emitted when the vault is created.
    /// @param vault Vault address.
    /// @param assetRegistry Asset registry address.
    /// @param hooks Hooks address.
    /// @param owner Initial owner address.
    /// @param guardian Guardian address.
    /// @param feeRecipient Fee recipient address.
    /// @param fee Fee accrued per second, denoted in 18 decimal fixed point format.
    /// @param description Vault description.
    /// @param wrappedNativeToken The address of wrapped native token.
    event VaultCreated(
        address indexed vault,
        address assetRegistry,
        address hooks,
        address indexed owner,
        address indexed guardian,
        address feeRecipient,
        uint256 fee,
        string description,
        address wrappedNativeToken
    );

    /// @notice Emitted when the asset registry is created.
    /// @param assetRegistry Asset registry address.
    /// @param vault Vault address.
    /// @param owner Initial owner address.
    /// @param assets Initial list of registered assets.
    /// @param numeraireToken Numeraire token address.
    /// @param feeToken Fee token address.
    /// @param sequencer Sequencer Uptime Feed address for L2.
    event AssetRegistryCreated(
        address indexed assetRegistry,
        address indexed vault,
        address indexed owner,
        IAssetRegistry.AssetInformation[] assets,
        IERC20 numeraireToken,
        IERC20 feeToken,
        AggregatorV2V3Interface sequencer
    );

    /// @notice Emitted when the hooks is created.
    /// @param hooks Hooks address.
    /// @param vault Vault address.
    /// @param owner Initial owner address.
    /// @param maxDailyExecutionLoss The fraction of value that the vault can
    ///                               lose per day in the course of submissions.
    /// @param targetSighashAllowlist Array of target contract and sighash combinations to allow.
    event HooksCreated(
        address indexed hooks,
        address indexed vault,
        address indexed owner,
        uint256 maxDailyExecutionLoss,
        TargetSighashData[] targetSighashAllowlist
    );

    /// ERRORS ///

    error Aera__DescriptionIsEmpty();
    error Aera__WrappedNativeTokenIsZeroAddress();
    error Aera__InvalidWrappedNativeToken();

    /// FUNCTIONS ///

    /// @notice Initialize the factory contract.
    /// @param wrappedNativeToken_ The address of wrapped native token.
    constructor(address wrappedNativeToken_) Ownable() {
        if (wrappedNativeToken_ == address(0)) {
            revert Aera__WrappedNativeTokenIsZeroAddress();
        }
        if (wrappedNativeToken_.code.length == 0) {
            revert Aera__InvalidWrappedNativeToken();
        }
        try IERC20(wrappedNativeToken_).balanceOf(address(this)) returns (
            uint256
        ) {} catch {
            revert Aera__InvalidWrappedNativeToken();
        }

        wrappedNativeToken = wrappedNativeToken_;
    }

    /// @inheritdoc IAeraV2Factory
    function create(
        bytes32 saltInput,
        address owner_,
        address guardian,
        address feeRecipient,
        uint256 fee,
        string calldata description,
        AssetRegistryParameters calldata assetRegistryParameters,
        HooksParameters calldata hooksParameters
    )
        external
        override
        onlyOwner
        returns (
            address deployedVault,
            address deployedAssetRegistry,
            address deployedHooks
        )
    {
        // Requirements: confirm that vault has a nonempty description.
        if (bytes(description).length == 0) {
            revert Aera__DescriptionIsEmpty();
        }

        bytes32 salt = _calculateSalt(
            saltInput, owner_, guardian, feeRecipient, fee, description
        );

        {
            address vaultAddress = _computeVaultAddress(salt);

            // Effects: deploy asset registry.
            deployedAssetRegistry = _deployAssetRegistry(
                salt, vaultAddress, assetRegistryParameters
            );

            // Effects: deploy first instance of hooks.
            deployedHooks = _deployHooks(salt, vaultAddress, hooksParameters);
        }

        // Effects: deploy the vault.
        deployedVault = _deployVault(
            salt,
            owner_,
            deployedAssetRegistry,
            deployedHooks,
            guardian,
            feeRecipient,
            fee,
            description
        );
    }

    /// @inheritdoc IAeraV2Factory
    function computeVaultAddress(
        bytes32 saltInput,
        address owner_,
        address guardian,
        address feeRecipient,
        uint256 fee,
        string calldata description
    ) external view override returns (address) {
        return _computeVaultAddress(
            _calculateSalt(
                saltInput, owner_, guardian, feeRecipient, fee, description
            )
        );
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
        // Effects: deploy asset registry.
        deployed = IAeraVaultAssetRegistryFactory(
            assetRegistryParameters.factory
        ).deployAssetRegistry(
            salt,
            assetRegistryParameters.owner,
            vault,
            assetRegistryParameters.assets,
            assetRegistryParameters.numeraireToken,
            assetRegistryParameters.feeToken,
            assetRegistryParameters.sequencer
        );

        // Log asset registry creation.
        emit AssetRegistryCreated(
            deployed,
            vault,
            assetRegistryParameters.owner,
            assetRegistryParameters.assets,
            assetRegistryParameters.numeraireToken,
            assetRegistryParameters.feeToken,
            assetRegistryParameters.sequencer
        );
    }

    /// @notice Deploy hooks.
    /// @param salt The salt value to deploy hooks.
    /// @param vault Vault address.
    /// @param hooksParameters Struct details for hooks deployment.
    /// @return deployed The address of deployed hooks.
    function _deployHooks(
        bytes32 salt,
        address vault,
        HooksParameters memory hooksParameters
    ) internal returns (address deployed) {
        // Effects: deploy hooks.
        deployed = IAeraVaultHooksFactory(hooksParameters.factory).deployHooks(
            salt,
            hooksParameters.owner,
            vault,
            hooksParameters.maxDailyExecutionLoss,
            hooksParameters.targetSighashAllowlist
        );

        // Log hooks creation.
        emit HooksCreated(
            deployed,
            vault,
            hooksParameters.owner,
            hooksParameters.maxDailyExecutionLoss,
            hooksParameters.targetSighashAllowlist
        );
    }

    /// @notice Deploy V2 vault.
    /// @param salt The salt value to create vault.
    /// @param owner_ Initial owner address.
    /// @param assetRegistry Asset registry address.
    /// @param hooks Hooks address.
    /// @param guardian Guardian address.
    /// @param feeRecipient Fee recipient address.
    /// @param fee Fee accrued per second, denoted in 18 decimal fixed point format.
    /// @param description Vault description.
    /// @return deployed The address of deployed vault.
    function _deployVault(
        bytes32 salt,
        address owner_,
        address assetRegistry,
        address hooks,
        address guardian,
        address feeRecipient,
        uint256 fee,
        string calldata description
    ) internal returns (address deployed) {
        parameters = VaultParameters(
            owner_, assetRegistry, hooks, guardian, feeRecipient, fee
        );

        // Requirements, Effects and Interactions: deploy vault with create2.
        deployed = address(new AeraVaultV2{salt: salt}());

        delete parameters;

        // Log vault creation.
        emit VaultCreated(
            deployed,
            assetRegistry,
            hooks,
            owner_,
            guardian,
            feeRecipient,
            fee,
            description,
            wrappedNativeToken
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

    /// @notice Calculate salt from vault parameters.
    /// @param saltInput The salt value to create vault.
    /// @param owner_ Initial owner address.
    /// @param guardian Guardian address.
    /// @param feeRecipient Fee recipient address.
    /// @param fee Fee accrued per second, denoted in 18 decimal fixed point format.
    /// @param description Vault description.
    function _calculateSalt(
        bytes32 saltInput,
        address owner_,
        address guardian,
        address feeRecipient,
        uint256 fee,
        string calldata description
    ) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                saltInput, owner_, guardian, feeRecipient, fee, description
            )
        );
    }
}
