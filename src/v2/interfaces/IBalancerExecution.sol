// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./IExecution.sol";

/// @title Interface for BalancerExecution module.
interface IBalancerExecution is IExecution {
    // Use struct parameter to avoid stack too deep error.
    /// @param factory Balancer Managed Pool Factory address.
    /// @param name Name of Pool Token.
    /// @param symbol Symbol of Pool Token.
    /// @param poolTokens Pool token addresses.
    /// @param weights Token weights.
    /// @param swapFeePercentage Pool swap fee.
    /// @param assetRegistry The address of asset registry.
    /// @param description Simple vault text description.
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

    /// @notice Initialize Vault with first deposit.
    /// @param vault Address of vault contract.
    function initialize(address vault) external;

    /// @notice Return the address of vault's asset registry.
    /// @return assetRegistry The address of asset registry.
    function assetRegistry()
        external
        view
        returns (IAssetRegistry assetRegistry);

    /// @notice Return currently listed assets in Balancer pool.
    /// @return assets List of assets.
    function assets() external view returns (IERC20[] memory assets);

    /// @notice Return Balancer Vault.
    function bVault() external view returns (IBVault bVault);

    /// @notice Return Balancer Managed Pool.
    function pool() external view returns (IBManagedPool pool);

    /// @notice Return Pool ID of Balancer Pool on Vault.
    function poolId() external view returns (bytes32 poolId);

    /// @notice Timestamp at when rebalancing ends.
    function epochEndTime() external view returns (uint256 epochEndTime);
}
