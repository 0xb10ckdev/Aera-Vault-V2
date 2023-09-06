// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/IERC20.sol";

/// @title Interface for sweepable module.
interface ISweepable {
    /// @notice Emitted when sweep is called.
    /// @param token Token address.
    /// @param amount Withdrawn amount of token.
    event Sweep(address token, uint256 amount);

    /// @notice Withdraw any tokens accidentally sent to contract.
    /// @param token Token address to withdraw.
    function sweep(address token) external;
}
