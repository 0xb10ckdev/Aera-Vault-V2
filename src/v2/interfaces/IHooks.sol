// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "./IHooksEvents.sol";
import {AssetValue, Operation} from "../Types.sol";

/// @title IHooks
/// @notice Interface for the hooks module.
interface IHooks is IHooksEvents {
    /// @notice Get address of custody module.
    /// @return custody Custody module address.
    function custody() external view returns (address custody);

    /// @notice Hook that runs before deposit.
    /// @param amounts Struct details for assets and amounts to deposit.
    /// @dev MUST revert if not called by custody.
    function beforeDeposit(AssetValue[] memory amounts) external;

    /// @notice Hook that runs after deposit.
    /// @param amounts Struct details for assets and amounts to deposit.
    /// @dev MUST revert if not called by custody.
    function afterDeposit(AssetValue[] memory amounts) external;

    /// @notice Hook that runs before withdraw.
    /// @param amounts Struct details for assets and amounts to withdraw.
    /// @dev MUST revert if not called by custody.
    function beforeWithdraw(AssetValue[] memory amounts) external;

    /// @notice Hook that runs after withdraw.
    /// @param amounts Struct details for assets and amounts to withdraw.
    /// @dev MUST revert if not called by custody.
    function afterWithdraw(AssetValue[] memory amounts) external;

    /// @notice Hook that runs before submit.
    /// @param operations Array of struct details for target and calldata to submit.
    /// @dev MUST revert if not called by custody.
    function beforeSubmit(Operation[] memory operations) external;

    /// @notice Hook that runs after submit.
    /// @param operations Array of struct details for target and calldata to submit.
    /// @dev MUST revert if not called by custody.
    function afterSubmit(Operation[] memory operations) external;

    /// @notice Hook that runs before finalize.
    /// @dev MUST revert if not called by custody.
    function beforeFinalize() external;

    /// @notice Hook that runs after finalize.
    /// @dev MUST revert if not called by custody.
    function afterFinalize() external;
}
