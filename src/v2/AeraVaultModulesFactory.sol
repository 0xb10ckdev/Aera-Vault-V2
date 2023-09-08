// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/IERC20.sol";
import "@openzeppelin/Ownable2Step.sol";
import "./AeraVaultAssetRegistry.sol";
import "./AeraVaultHooks.sol";
import "./interfaces/IAeraVaultAssetRegistryFactory.sol";
import "./interfaces/IAeraVaultHooksFactory.sol";

/// @title AeraVaultModulesFactory
/// @notice Used to create new vaults and deploy arbitrary non-payable contracts with create2.
/// @dev Only one instance of the factory will be required per chain.
contract AeraVaultModulesFactory is
    IAeraVaultAssetRegistryFactory,
    IAeraVaultHooksFactory,
    Ownable2Step
{
    /// @notice The address of the v2 factory.
    address public immutable v2Factory;

    /// EVENTS ///

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

    /// MODIFIERS ///

    error Aera_CallerIsNeitherOwnerOrV2Factory();
    error Aera__V2FactoryIsZeroAddress();

    /// MODIFIERS ///

    /// @dev Throws if called by any account other than the vault.
    modifier onlyOwnerOrV2Factory() {
        if (msg.sender != owner() && msg.sender != v2Factory) {
            revert Aera_CallerIsNeitherOwnerOrV2Factory();
        }
        _;
    }

    /// FUNCTIONS ///

    constructor(address v2Factory_) Ownable() {
        if (v2Factory_ == address(0)) {
            revert Aera__V2FactoryIsZeroAddress();
        }

        v2Factory = v2Factory_;
    }

    /// @inheritdoc IAeraVaultAssetRegistryFactory
    function deployAssetRegistry(
        bytes32 salt,
        address owner_,
        address vault,
        IAssetRegistry.AssetInformation[] memory assets,
        IERC20 numeraireToken,
        IERC20 feeToken,
        AggregatorV2V3Interface sequencer
    ) external override onlyOwnerOrV2Factory returns (address deployed) {
        // Effects: deploy asset registry.
        deployed = address(
            new AeraVaultAssetRegistry{salt: salt}(
                owner_,
                vault,
                assets,
                numeraireToken,
                feeToken,
                sequencer
            )
        );

        // Log asset registry creation.
        emit AssetRegistryCreated(
            deployed,
            vault,
            owner_,
            assets,
            numeraireToken,
            feeToken,
            sequencer
        );
    }

    /// @inheritdoc IAeraVaultHooksFactory
    function deployHooks(
        bytes32 salt,
        address owner_,
        address vault,
        uint256 maxDailyExecutionLoss,
        TargetSighashData[] memory targetSighashAllowlist
    ) external override onlyOwnerOrV2Factory returns (address deployed) {
        // Effects: deploy hooks.
        deployed = address(
            new AeraVaultHooks{salt:salt}(
                owner_,
                vault,
                maxDailyExecutionLoss,
                targetSighashAllowlist
            )
        );

        // Log hooks creation.
        emit HooksCreated(
            deployed,
            vault,
            owner_,
            maxDailyExecutionLoss,
            targetSighashAllowlist
        );
    }
}
