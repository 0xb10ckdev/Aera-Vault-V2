// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/IERC20.sol";
import "./IHooksEvents.sol";
import {AssetValue, Operation} from "../Types.sol";

/// @title Interface for hooks module.
interface IHooks is IHooksEvents {
    /// ERRORS ///

    error Aera__CallerIsNotCustody();
    error Aera__CustodyIsZeroAddress();
    error Aera__CustodyIsNotValid(address custody);
    error Aera__TargetIsHooks();
    error Aera__CallIsNotAllowed(Operation operation);
    error Aera__ExceedsMaxDailyExecutionLoss();

    /// FUNCTIONS ///

    function addTargetSighash(TargetSighash targetSighash) external;

    function removeTargetSighash(TargetSighash targetSighash) external;

    function beforeDeposit(AssetValue[] memory amounts) external;

    function afterDeposit(AssetValue[] memory amounts) external;

    function beforeWithdraw(AssetValue[] memory amounts) external;

    function afterWithdraw(AssetValue[] memory amounts) external;

    function beforeSubmit(Operation[] memory operation) external;

    function afterSubmit(Operation[] memory operation) external;

    function beforeFinalize() external;

    function afterFinalize() external;
}
