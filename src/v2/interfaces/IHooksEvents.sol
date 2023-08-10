// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {TargetSighash} from "../Types.sol";

/// @title Interface for hooks module.
interface IHooksEvents {
    /// @notice Emitted when targetSighash is added to allowlist.
    /// @param target Address of target.
    /// @param selector Selector of function.
    event TargetSighashAdded(address target, bytes4 selector);

    /// @notice Emitted when targetSighash is removed from allowlist.
    /// @param target Address of target.
    /// @param selector Selector of function.
    event TargetSighashRemoved(address target, bytes4 selector);
}
