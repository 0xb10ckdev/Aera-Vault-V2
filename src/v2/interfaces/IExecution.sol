// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../dependencies/openzeppelin/IERC20.sol";
import "./IAssetRegistry.sol";
import "./IBManagedPool.sol";
import "./IBVault.sol";
import "./IExecutionEvents.sol";
import "./ISweepable.sol";

/// @title Interface for execution module.
interface IExecution is IExecutionEvents, ISweepable {
    /// TYPES ///

    /// @param asset Address of asset.
    /// @param amount Amount of asset to rebalance.
    /// @param weight Target weight of asset.
    struct AssetRebalanceRequest {
        IERC20 asset;
        uint256 amount;
        uint256 weight;
    }

    /// @param asset Address of asset.
    /// @param value Value of asset.
    struct AssetValue {
        IERC20 asset;
        uint256 value;
    }

    /// ERRORS ///

    error Aera__AssetRegistryIsZeroAddress();
    error Aera__CallerIsNotVault();
    error Aera__SumOfWeightsIsNotOne();
    error Aera__WeightChangeEndBeforeStart();
    error Aera__RebalancingHasNotStarted();
    error Aera__RebalancingIsOnGoing(uint256 endTime);

    /// FUNCTIONS ///

    /// @notice Attempt to change the distribution of ERC20 assets in the vault
    ///         to a target distribution.
    /// @param requests Struct details for requests.
    /// @param startTime Timestamp at which weight movement should start.
    /// @param endTime Timestamp at which the weights should reach target values.
    function startRebalance(
        AssetRebalanceRequest[] memory requests,
        uint256 startTime,
        uint256 endTime
    ) external;

    /// @notice Claim funds from prior rebalance.
    function endRebalance() external;

    /// @notice Return all funds in execution module to vault.
    function claimNow() external;

    /// @notice Return the address of vault's asset registry.
    /// @return assetRegistry The address of asset registry.
    function assetRegistry()
        external
        view
        returns (IAssetRegistry assetRegistry);

    /// @notice Get the current vault contract that the execution layer is linked to.
    /// @return vault Address of linked vault contract.
    function vault() external view returns (address vault);

    /// @notice Return amount of each asset in the execution module.
    /// @return holdings Amount of each asset.
    function holdings() external view returns (AssetValue[] memory holdings);

    /// @notice Timestamp at when rebalancing ends.
    function rebalanceEndTime()
        external
        view
        returns (uint256 rebalanceEndTime);
}
