// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../dependencies/chainlink/interfaces/AggregatorV2V3Interface.sol";
import "../dependencies/openzeppelin/IERC20.sol";

/// @title Interface for vault asset registry.
interface IAssetRegistry {
    /// @param asset Address of an asset.
    /// @param isERC4626 True if yield-bearing asset, false if plain ERC20 asset.
    /// @param withdrawable True if can be directly withdrawn by owner (this applies to ERC4626 assets only).
    /// @param oracle If applicable, oracle address for asset.
    struct AssetInformation {
        IERC20 asset;
        bool isERC4626;
        bool withdrawable;
        AggregatorV2V3Interface oracle;
    }

    /// @param asset Address of an asset.
    /// @param weight Weight of an asset.
    struct AssetWeight {
        IERC20 asset;
        uint256 weight;
    }

    /// @param asset Address of an asset.
    /// @param spotPrice Spot price of an asset in numeraire asset terms.
    struct AssetPriceReading {
        IERC20 asset;
        uint256 spotPrice;
    }

    /// @notice Get a list of all active assets for the vault.
    /// @return assets List of assets.
    function assets() external view returns (AssetInformation[] memory assets);

    /// @notice Get the index of the numeraire asset in the assets array.
    /// @return numeraire Index of numeraire asset.
    function numeraire() external view returns (uint256 numeraire);

    /// @notice Get the number of ERC4626 assets.
    /// @return numYieldAssets Number of ERC4626 assets.
    function numYieldAssets() external view returns (uint256 numYieldAssets);

    /// @notice Add a new asset.
    /// @param asset A new asset to add.
    function addAsset(AssetInformation memory asset) external;

    /// @notice Remove an asset.
    /// @param asset An asset to remove.
    function removeAsset(address asset) external;

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

    /// @notice Calculate spot prices of non-ERC4626 assets.
    /// @return spotPrices Spot prices of non-ERC4626 assets.
    function spotPrices()
        external
        view
        returns (AssetPriceReading[] memory spotPrices);
}
