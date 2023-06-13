// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/IERC20.sol";

/// @title Interface for sweep events.
interface ISweepableEvents {
    /// @notice Emitted when sweep is called.
    /// @param asset Address of asset.
    /// @param amount Amount of asset.
    event Sweep(IERC20 asset, uint256 amount);
}
