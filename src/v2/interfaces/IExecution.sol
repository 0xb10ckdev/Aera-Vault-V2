// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../dependencies/openzeppelin/IERC20.sol";
import "./IAssetRegistry.sol";
import "./IBManagedPool.sol";
import "./IBVault.sol";

/// @title Interface for execution module.
interface IExecution {
    /// TYPES ///

    /// @param asset Address of an asset.
    /// @param amount Amount of an asset to rebalance.
    /// @param weight Target weight of an asset.
    struct AssetRebalanceRequest {
        IERC20 asset;
        uint256 amount;
        uint256 weight;
    }

    /// @param asset Address of an asset.
    /// @param value Value of an asset.
    struct AssetValue {
        IERC20 asset;
        uint256 value;
    }

    /// ERRORS ///

    error Aera__CallerIsNotVault();
    error Aera__SumOfWeightIsNotOne();
    error Aera__WeightChangeEndBeforeStart();

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

    /// @notice Return funds from previous rebalancing epoch to vault.
    function claimNow() external;

    /// @notice Return a non-listed asset to the owner.
    /// @param asset Address of an asset.
    function sweep(IERC20 asset) external;

    /// @notice Get the current vault contract that the execution layer is linked to.
    /// @return vault Address of linked vault contract.
    function vault() external view returns (address vault);

    /// @notice Return amount of each asset in the execution module.
    function holdings() external view returns (AssetValue[] memory holdings);
}
