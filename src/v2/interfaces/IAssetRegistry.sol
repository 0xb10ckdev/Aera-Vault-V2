// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@chainlink/interfaces/AggregatorV2V3Interface.sol";
import "@openzeppelin/IERC20.sol";

/// @title Interface for vault asset registry.
interface IAssetRegistry {
    /// @param asset Address of an asset.
    /// @param isERC4626 True if yield-bearing asset, false if plain ERC20 asset.
    /// @param oracle If applicable, oracle address for asset.
    struct AssetInformation {
        IERC20 asset;
        bool isERC4626;
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
    function assets()
        external
        view
        returns (AssetInformation[] memory assets);

    /// @notice Get address of fee token.
    /// @return feeToken Address of fee token.
    function feeToken() external view returns (IERC20 feeToken);

    /// @notice Get the index of the numeraire asset in the assets array.
    /// @return numeraireId Index of numeraire asset.
    function numeraireId() external view returns (uint256 numeraireId);

    /// @notice Add a new asset.
    /// @param asset A new asset to add.
    function addAsset(AssetInformation memory asset) external;

    /// @notice Remove an asset.
    /// @param asset An asset to remove.
    function removeAsset(address asset) external;

    /// @notice Sets current custody module.
    /// @param custody Address of new custody module.
    function setCustody(address custody) external;

    /// @notice Calculate spot prices of non-ERC4626 assets.
    /// @return spotPrices Spot prices of non-ERC4626 assets.
    function spotPrices()
        external
        view
        returns (AssetPriceReading[] memory spotPrices);
}
