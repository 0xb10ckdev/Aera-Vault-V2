// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@chainlink/interfaces/AggregatorV2V3Interface.sol";
import "@openzeppelin/IERC20.sol";

/// @title IAssetRegistry
/// @notice Asset registry interface.
/// @dev Any implementation MUST also implement Ownable2Step and ERC165.
interface IAssetRegistry {
    /// @param asset Asset address.
    /// @param isERC4626 True if yield-bearing asset, false if just an ERC20 asset.
    /// @param oracle If applicable, oracle address for asset.
    /// @param heartbeat Frequency of oracle price updates.
    struct AssetInformation {
        IERC20 asset;
        bool isERC4626;
        AggregatorV2V3Interface oracle;
        uint256 heartbeat;
    }

    /// @param asset Asset address.
    /// @param spotPrice Spot price of an asset in numeraire asset terms.
    struct AssetPriceReading {
        IERC20 asset;
        uint256 spotPrice;
    }

    /// @notice Get address of vault.
    /// @return vault Address of vault.
    function vault() external view returns (address vault);

    /// @notice Get a list of all registered assets.
    /// @return assets List of assets.
    /// @dev MUST return assets in an order sorted by address.
    function assets()
        external
        view
        returns (AssetInformation[] memory assets);

    /// @notice Get address of fee token.
    /// @return feeToken Address of fee token.
    /// @dev Represented as an address for efficiency reasons.
    /// @dev MUST be present in assets array.
    function feeToken() external view returns (IERC20 feeToken);

    /// @notice Get the index of the numeraire asset in the assets array.
    /// @return numeraireId Index of numeraire asset.
    /// @dev Represented as an index for efficiency reasons.
    /// @dev MUST be a number between 0 (inclusive) and the length of assets array (exclusive).
    function numeraireId() external view returns (uint256 numeraireId);

    /// @notice Add a new asset.
    /// @param asset Asset information for new asset.
    /// @dev MUST revert if not called by owner.
    /// @dev MUST revert if asset with the same address exists.
    function addAsset(AssetInformation memory asset) external;

    /// @notice Remove an asset.
    /// @param asset An asset to remove.
    /// @dev MUST revert if not called by owner.
    function removeAsset(address asset) external;

    /// @notice Calculate spot prices of non-ERC4626 assets.
    /// @return spotPrices Spot prices of non-ERC4626 assets.
    /// @dev MUST return assets in the same order as in assets but with ERC4626 assets filtered out.
    /// @dev MUST also include numeraire asset (spot price = 1).
    /// @dev MAY revert if oracle prices for any asset are unreliable at the time.
    function spotPrices()
        external
        view
        returns (AssetPriceReading[] memory spotPrices);
}
