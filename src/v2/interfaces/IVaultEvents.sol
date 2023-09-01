// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {AssetValue, Operation} from "../Types.sol";

/// @title Interface for vault events.
interface IVaultEvents {
    /// @notice Emitted when deposit is called.
    /// @param owner Owner address.
    /// @param amounts Struct details for deposited assets and amounts.
    event Deposit(address indexed owner, AssetValue[] amounts);

    /// @notice Emitted when withdraw is called.
    /// @param owner Owner address.
    /// @param amounts Struct details for withdrawn assets and amounts.
    event Withdraw(address indexed owner, AssetValue[] amounts);

    /// @notice Emitted when guardian is set.
    /// @param guardian Address of new guardian.
    /// @param feeRecipient Address of new fee recipient.
    event SetGuardianAndFeeRecipient(
        address indexed guardian, address indexed feeRecipient
    );

    /// @notice Emitted when asset registry is set.
    /// @param assetRegistry Address of new asset registry.
    event SetAssetRegistry(address assetRegistry);

    /// @notice Emitted when hooks is set.
    /// @param hooks Address of new hooks.
    event SetHooks(address hooks);

    /// @notice Emitted when execute is called.
    /// @param owner Owner address.
    /// @param operation Struct details for target and calldata.
    event Executed(address indexed owner, Operation operation);

    /// @notice Emitted when vault is finalized.
    /// @param owner Owner address.
    /// @param withdrawnAmounts Struct details for withdrawn assets and amounts (sent to owner).
    event Finalized(address indexed owner, AssetValue[] withdrawnAmounts);

    /// @notice Emitted when submit is called.
    /// @param owner Owner address.
    /// @param operations Array of struct details for targets and calldatas.
    event Submitted(address indexed owner, Operation[] operations);

    /// @notice Emitted when guardian fees are claimed.
    /// @param feeRecipient Fee recipient address.
    /// @param claimedFee Claimed amount of fee token.
    /// @param unclaimedFee Unclaimed amount of fee token (unclaimed because Vault does not have enough balance of feeToken).
    event Claimed(
        address indexed feeRecipient, uint256 claimedFee, uint256 unclaimedFee
    );
}
