// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/IERC20.sol";
import "./interfaces/IAssetRegistry.sol";

// Types.sol
//
// This file defines the types used in V2.

/// @notice Combination of contract address and sighash to be used in allowlist.
/// @dev It's packed as follows:
///      [target 160 bits] [selector 32 bits] [<empty> 64 bits]
type TargetSighash is bytes32;

/// @notice Struct encapulating an asset and an associated value.
/// @param asset Asset address.
/// @param value The associated value for this asset (e.g., amount or price).
struct AssetValue {
    IERC20 asset;
    uint256 value;
}

/// @notice Execution details for a vault operation.
/// @param target Target contract address.
/// @param value Native token amount.
/// @param data Calldata.
struct Operation {
    address target;
    uint256 value;
    bytes data;
}

/// @notice Contract address and sighash struct to be used in the public interface.
struct TargetSighashData {
    address target;
    bytes4 selector;
}

/// @notice Vault parameters for vault deployment.
/// @param owner Initial owner address.
/// @param assetRegistry Asset registry address.
/// @param guardian Guardian address.
/// @param feeRecipient Fee recipient address.
/// @param fee Fee accrued per second, denoted in 18 decimal fixed point format.
struct VaultParameters {
    address owner;
    address assetRegistry;
    address guardian;
    address feeRecipient;
    uint256 fee;
}

/// @notice Asset registry parameters for asset registry deployment.
/// @param owner Initial owner address.
/// @param assets Initial list of registered assets.
/// @param numeraireId The index of the numeraire asset in the assets array.
/// @param feeToken Fee token address.
struct AssetRegistryParameters {
    address owner;
    IAssetRegistry.AssetInformation[] assets;
    uint256 numeraireId;
    IERC20 feeToken;
}

/// @notice Hooks parameters for hooks deployment.
/// @param owner Initial owner address.
/// @param maxDailyExecutionLoss The fraction of value that the vault can
///                               lose per day in the course of submissions.
/// @param targetSighashAllowlist Array of target contract and sighash combinations to allow.
struct HooksParameters {
    address owner;
    uint256 maxDailyExecutionLoss;
    TargetSighash[] targetSighashAllowlist;
}
