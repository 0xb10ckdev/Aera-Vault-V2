// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../dependencies/openzeppelin/IERC20.sol";
import "./IAssetRegistry.sol";

/// @title Interface for execution module.
interface IExecution {
    // Use struct parameter to avoid stack too deep error.
    // factory: Balancer Managed Pool Factory address.
    // name: Name of Pool Token.
    // symbol: Symbol of Pool Token.
    // poolTokens: Pool token addresses.
    // weights: Token weights.
    // swapFeePercentage: Pool swap fee.
    // assetRegistry: The address of asset registry.
    // description: Simple vault text description.
    struct NewVaultParams {
        address factory;
        string name;
        string symbol;
        IERC20[] poolTokens;
        uint256[] weights;
        uint256 swapFeePercentage;
        address assetRegistry;
        string description;
    }

    /// @param asset Address of an asset.
    /// @param amount Amount of an asset to rebalance.
    /// @param weight Target weight of an asset.
    struct AssetRebalanceRequest {
        IERC20 asset;
        uint256 amount;
        uint256 weight;
    }

    /// @notice Initialize Vault with first deposit.
    /// @param vault Address of vault contract.
    function initialize(address vault) external;

    /// @notice Attempt to change the distribution of ERC20 assets in the vault
    ///         to a target distribution.
    /// @param requests Struct details for requests.
    /// @param startTime Timestamp at which weight movement should start.
    /// @param endTime Timestamp at which the weights should reach target values.
    function claimAndRebalanceGradually(
        AssetRebalanceRequest[] memory requests,
        uint256 startTime,
        uint256 endTime
    ) external;

    /// @notice Return funds from previous rebalancing epoch to vault.
    function claimNow() external;

    /// @notice Return a non-listed asset to the owner.
    /// @param asset Address of an asset.
    function sweep(IERC20 asset) external;

    /// @notice Get the current vault contract that the execution layer is linked to.
    /// @return vault Address of linked vault contract.
    function vault() external view returns (address vault);

    /// @notice Return the address of vault's asset registry.
    /// @return assetRegistry The address of asset registry.
    function assetRegistry()
        external
        view
        returns (IAssetRegistry assetRegistry);

    /// @notice Return currently listed assets in Balancer pool.
    /// @return assets List of assets.
    function assets() external view returns (IERC20[] memory assets);
}
