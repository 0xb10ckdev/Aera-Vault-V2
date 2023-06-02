// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./IExecution.sol";

/// @title Interface for UniswapV3 Execution module.
interface IUniswapV3Execution is IExecution {
    // NOTE: The ordering should always be asset0 < asset1
    struct PoolPreference {
        IERC20 asset0; // first asset
        IERC20 asset1; // second asset
        address pool; // preferred Uni V3 pool for the asset pair
    }

    // Use struct parameter to avoid stack too deep error.
    /// @param assetRegistry Asset Registry address.
    /// @param vehicle Used as an intermediate asset for trading. Must be in asset registry.
    /// @param maxSlippage Max slippage per-trade maximum slippage bound. Encoded as a fraction with 10^18 decimal fixed point implementation.
    /// @param poolPreferences Preferred Uni V3 pool for specified asset pairs
    /// @param description Simple text describing execution module.
    struct NewUniswapV3ExecutionParams {
        address assetRegistry;
        address vehicle;
        uint256 maxSlippage;
        IUniswapV3Execution.PoolPreference[] poolPreferences;
        string description;
    }

    struct TradePair {
        IERC20 assetIn;
        IERC20 assetOut;
        uint256 amount;
        address pool;
    }

    /// @notice Return the address of vault's asset registry.
    /// @return assetRegistry The address of asset registry.
    function assetRegistry()
        external
        view
        returns (IAssetRegistry assetRegistry);
}
