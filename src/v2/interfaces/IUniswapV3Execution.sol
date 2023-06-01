// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./IExecution.sol";

/// @title Interface for BalancerExecution module.
interface IUniswapV3Execution is IExecution {
    // NOTE: The ordering should always be asset0 < asset1
    struct PoolPreference {
        asset0: IERC20, // first asset
        asset1: IERC20, // second asset
        pool: IERC20, // preferred Uni V3 pool for the asset pair
    }

    // Use struct parameter to avoid stack too deep error.
    /// @param assetRegistry Asset Registry address. // TODO: can we get pool addresses from asset addresses in registry?
    /// @param vehicle Used as an intermediate asset for trading. Must be in asset registry.
    /// @param maxSlippage Max slippage per-trade maximum slippage bound. Encoded as a fraction with 10^18 decimal fixed point implementation.
    /// @param poolPreferences preferred Uni V3 pool for specified asset pairs
    /// @param description Simple text describing execution module.
    struct NewUniswapV3ExecutionParams {
        address assetRegistry;
        address vehicle;
        uint256 maxSlippage;
        PoolPreference[] poolPreferences;
        string description;
    }

    /// @notice Return the address of vault's asset registry.
    /// @return assetRegistry The address of asset registry.
    function assetRegistry()
        external
        view
        returns (IAssetRegistry assetRegistry);

    /// @notice address of vehicle used as an intermediate asset for trading. Must be in asset registry.
    function vehicle() external view returns (address vehicle);

    /// @notice Return max slippage per-trade maximum slippage bound. Encoded as a fraction with 10^18 decimal fixed point implementation.
    function maxSlippage() external view returns (uint256 maxSlippage);
}
