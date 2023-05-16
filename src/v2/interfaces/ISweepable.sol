// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./ISweepableEvents.sol";

/// @title Interface for sweepable module.
interface ISweepable is ISweepableEvents {
    /// @notice Return an asset to the owner.
    /// @param token Address of token.
    /// @param amount Amount of token.
    function sweep(IERC20 token, uint256 amount) external;
}
