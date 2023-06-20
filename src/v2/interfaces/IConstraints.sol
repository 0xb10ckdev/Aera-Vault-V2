// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/IERC20.sol";
import "./IAssetRegistry.sol";
import "./IConstraintsEvents.sol";
import "./ICustody.sol";

/// @title Interface for constraints module.
interface IConstraints is IConstraintsEvents {
    /// TYPES ///

    /// @param asset Address of an asset.
    /// @param weight Weight of an asset.
    struct AssetWeight {
        IERC20 asset;
        uint256 weight;
    }

    /// ERRORS ///

    error Aera__AssetRegistryIsZeroAddress();
    error Aera__AssetRegistryIsNotValid(address assetRegistry);
    error Aera__CustodyIsZeroAddress();
    error Aera__CustodyIsNotValid(address custody);

    /// FUNCTIONS ///

    /// @notice Get the current custody module.
    /// @return custody Address of custody module.
    function custody() external view returns (ICustody custody);

    /// @notice Get the current asset registry.
    /// @return assetRegistry Address of asset registry.
    function assetRegistry()
        external
        view
        returns (IAssetRegistry assetRegistry);

    /// @notice Sets current asset registry.
    /// @param assetRegistry Address of new asset registry.
    function setAssetRegistry(address assetRegistry) external;

    /// @notice Sets current custody module.
    /// @param custody Address of new custody module.
    function setCustody(address custody) external;

    /// @notice Check if submitter weights are valid.
    /// @param currentWeights Current weights of assets.
    /// @param targetWeights Target weights of assets.
    /// @param duration Weight change duration.
    /// @return valid True if weights are valid.
    function checkWeights(
        AssetWeight[] memory currentWeights,
        AssetWeight[] memory targetWeights,
        uint256 duration
    ) external view returns (bool valid);
}
