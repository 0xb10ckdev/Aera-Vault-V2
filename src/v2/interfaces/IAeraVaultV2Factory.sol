// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {TargetSighash} from "../Types.sol";

/// @title Interface for v2 vault factory.
interface IAeraVaultV2Factory {
    /// @notice Create v2 vault.
    /// @param assetRegistry The address of asset registry.
    /// @param guardian The address of guardian.
    /// @param feeRecipient The address of fee recipient.
    /// @param fee Guardian fee per second in 18 decimal fixed point format.
    /// @param maxDailyExecutionLoss  The fraction of value that the vault can
    ///                                lose per day in the course of submissions.
    /// @param targetSighashAllowlist Array of target sighash to allow.
    function create(
        address assetRegistry,
        address guardian,
        address feeRecipient,
        uint256 fee,
        uint256 maxDailyExecutionLoss,
        TargetSighash[] memory targetSighashAllowlist
    ) external;
}
