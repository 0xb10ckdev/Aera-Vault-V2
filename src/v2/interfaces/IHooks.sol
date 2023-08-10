// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "./IHooksEvents.sol";
import {AssetValue, Operation} from "../Types.sol";

/// @title Interface for hooks module.
interface IHooks is IHooksEvents {
    /// ERRORS ///

    error Aera__CallerIsNotCustody();
    error Aera__CustodyIsZeroAddress();
    error Aera__CustodyIsNotValid(address custody);
    error Aera__CallIsNotAllowed(Operation operation);
    error Aera__ExceedsMaxDailyExecutionLoss();
    error Aera__AllowanceIsNotZero(address asset, address spender);

    /// FUNCTIONS ///

    /// @notice Add targetSighash pair to allowlist.
    /// @param target Address of target.
    /// @param selector Selector of function.
    function addTargetSighash(address target, bytes4 selector) external;

    /// @notice Remove targetSighash pair from allowlist.
    /// @param target Address of target.
    /// @param selector Selector of function.
    function removeTargetSighash(address target, bytes4 selector) external;

    /// @notice Hook that runs before deposit.
    /// @param amounts Struct details for assets and amounts to deposit.
    function beforeDeposit(AssetValue[] memory amounts) external;

    /// @notice Hook that runs after deposit.
    /// @param amounts Struct details for assets and amounts to deposit.
    function afterDeposit(AssetValue[] memory amounts) external;

    /// @notice Hook that runs before withdraw.
    /// @param amounts Struct details for assets and amounts to withdraw.
    function beforeWithdraw(AssetValue[] memory amounts) external;

    /// @notice Hook that runs after withdraw.
    /// @param amounts Struct details for assets and amounts to withdraw.
    function afterWithdraw(AssetValue[] memory amounts) external;

    /// @notice Hook that runs before submit.
    /// @param operations Array of struct details for target and calldata to submit.
    function beforeSubmit(Operation[] memory operations) external;

    /// @notice Hook that runs after submit.
    /// @param operations Array of struct details for target and calldata to submit.
    function afterSubmit(Operation[] memory operations) external;

    /// @notice Hook that runs before finalize.
    function beforeFinalize() external;

    /// @notice Hook that runs after finalize.
    function afterFinalize() external;
}
