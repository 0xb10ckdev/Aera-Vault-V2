// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../AeraVaultHooks.sol";
import "../AeraVaultV2.sol";
import {TargetSighash} from "../Types.sol";

/// @title Interface for v2 vault factory.
interface IAeraVaultV2Factory {
    /// @notice Create v2 vault.
    /// @param assetRegistry The address of asset registry.
    /// @param guardian The address of guardian.
    /// @param feeRecipient The address of fee recipient.
    /// @param fee Guardian fee per second in 18 decimal fixed point format.
    /// @return vault The address of deployed vault.
    function create(
        address assetRegistry,
        address guardian,
        address feeRecipient,
        uint256 fee
    ) external returns (AeraVaultV2 vault);
}
