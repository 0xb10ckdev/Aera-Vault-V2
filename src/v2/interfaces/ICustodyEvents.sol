// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../dependencies/openzeppelin/IERC20.sol";
import "./ICustody.sol";

/// @title Interface for custody module events.
interface ICustodyEvents {
    /// @notice Emitted when deposit is called.
    /// @param amounts Struct details for deposited amount.
    event Deposit(ICustody.AssetValue[] amounts);

    /// @notice Emitted when withdraw is called.
    /// @param amounts Struct details for withdrawal amount.
    /// @param force Whether it could touch assets on execution module or not.
    event Withdraw(ICustody.AssetValue[] amounts, bool force);

    /// @notice Emitted when guardian is set.
    /// @param guardian Address of new guardian.
    event SetGuardian(address guardian);

    /// @notice Emitted when asset registry is set.
    /// @param assetRegistry Address of new asset registry.
    event SetAssetRegistry(address assetRegistry);

    /// @notice Emitted when execution module is set.
    /// @param execution Address of new execution module.
    event SetExecution(address execution);

    /// @notice Emitted when vault is finalized.
    event Finalized();

    /// @notice Emitted when sweep is called.
    /// @param asset Address of asset.
    /// @param amount Amount of asset.
    event Sweep(IERC20 asset, uint256 amount);

    /// @notice Emitted when rebalancing is started.
    /// @param assetWeights Weights of assets to rebalance and target weight.
    /// @param startTime Timestamp at which weight movement should start.
    /// @param endTime Timestamp at which the weights should reach target values.
    event StartRebalance(
        ICustody.AssetValue[] assetWeights,
        uint256 startTime,
        uint256 endTime
    );

    ///@notice Emitted when endRebalance is called.
    event EndRebalance();

    ///@notice Emitted when endRebalanceEarly is called.
    event EndRebalanceEarly();

    ///@notice Emitted when guardian fees are claimed.
    /// @param guardian Guardian address.
    /// @param claimedFees Claimed amount of each assets.
    event ClaimGuardianFees(
        address guardian,
        ICustody.AssetValue[] claimedFees
    );
}
