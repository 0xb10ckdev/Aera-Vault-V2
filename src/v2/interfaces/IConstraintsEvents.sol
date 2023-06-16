// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

/// @title Interface for constraints module events.
interface IConstraintsEvents {
    /// @notice Emitted when asset registry is set.
    /// @param assetRegistry Address of new asset registry.
    event SetAssetRegistry(address assetRegistry);

    /// @notice Emitted when custody module is set.
    /// @param custody Address of new custody module.
    event SetCustody(address custody);
}
