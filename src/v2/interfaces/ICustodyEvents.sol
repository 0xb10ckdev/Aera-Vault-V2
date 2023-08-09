// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {AssetValue, Operation} from "../Types.sol";

/// @title Interface for custody module events.
interface ICustodyEvents {
    /// @notice Emitted when deposit is called.
    /// @param amounts Struct details for deposited assets and amounts.
    event Deposit(AssetValue[] amounts);

    /// @notice Emitted when withdraw is called.
    /// @param amounts Struct details for withdrawn assets and amounts.
    event Withdraw(AssetValue[] amounts);

    /// @notice Emitted when guardian is set.
    /// @param guardian Address of new guardian.
    /// @param feeRecipient Address of new fee recipient.
    event SetGuardianAndFeeRecipient(address guardian, address feeRecipient);

    /// @notice Emitted when asset registry is set.
    /// @param assetRegistry Address of new asset registry.
    event SetAssetRegistry(address assetRegistry);

    /// @notice Emitted when hooks is set.
    /// @param hooks Address of new hooks.
    event SetHooks(address hooks);

    /// @notice Emitted when execute is called.
    /// @param operation Struct details for target and calldata.
    event Executed(Operation operation);

    /// @notice Emitted when vault is finalized.
    event Finalized();

    /// @notice Emitted when submit is called.
    /// @param operations Array of struct details for targets and calldatas.
    event Submitted(Operation[] operations);

    /// @notice Emitted when guardian fees are claimed.
    /// @param guardian Guardian address.
    /// @param claimedFee Claimed amount of fee token.
    event Claimed(address guardian, uint256 claimedFee);
}
