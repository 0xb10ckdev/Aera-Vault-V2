// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

/// @title Interface for BalancerExecution module events.
interface IBalancerExecutionEvents {
    /// @notice Emitted when module is initialized.
    /// @param vault Address of Aera vault contract.
    event Initialize(address vault);
}
