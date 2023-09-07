// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {TargetSighashData} from "../Types.sol";

/// @title IAeraVaultHooksFactory
/// @notice Interface for the hooks factory.
interface IAeraVaultHooksFactory {
    /// @notice Deploy hooks.
    /// @param salt The salt value to deploy hooks.
    /// @param owner Initial owner address.
    /// @param vault Vault address.
    /// @param maxDailyExecutionLoss The fraction of value that the vault can
    ///                              lose per day in the course of submissions.
    /// @param targetSighashAllowlist Array of target contract and sighash combinations to allow.
    /// @return deployed The address of deployed hooks.
    function deployHooks(
        bytes32 salt,
        address owner,
        address vault,
        uint256 maxDailyExecutionLoss,
        TargetSighashData[] memory targetSighashAllowlist
    ) external returns (address deployed);
}
