// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/IERC20.sol";
import "./IExecution.sol";

/// @title Interface for execution module events.
interface IExecutionEvents {
    /// @notice Emitted when rebalancing is started.
    /// @param requests Each request specifies amount of asset to rebalance and target weight.
    /// @param startTime Timestamp at which weight movement should start.
    /// @param endTime Timestamp at which the weights should reach target values.
    event StartRebalance(
        IExecution.AssetRebalanceRequest[] requests,
        uint256 startTime,
        uint256 endTime
    );

    /// @notice Emitted when endRebalance is called.
    event EndRebalance();

    /// @notice Emitted when claimNow is called.
    event ClaimNow();
}
