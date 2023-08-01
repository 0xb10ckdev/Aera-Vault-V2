// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../AeraVaultHooks.sol";
import "../AeraVaultV2.sol";
import {TargetSighash} from "../Types.sol";

/// @title Interface for v2 vault factory.
interface IAeraVaultV2Factory {
    /// @notice Create v2 vault.
    /// @param salt The salt value to create vault.
    /// @param owner The address of initial owner.
    /// @param assetRegistry The address of asset registry.
    /// @param guardian The address of guardian.
    /// @param feeRecipient The address of fee recipient.
    /// @param fee Guardian fee per second in 18 decimal fixed point format.
    /// @return deployed The address of deployed vault.
    function create(
        bytes32 salt,
        address owner,
        address assetRegistry,
        address guardian,
        address feeRecipient,
        uint256 fee
    ) external returns (address deployed);

    /// @notice Calculate deployment address of v2 vault.
    /// @param salt The salt value to create vault.
    /// @param owner The address of initial owner.
    /// @param assetRegistry The address of asset registry.
    /// @param guardian The address of guardian.
    /// @param feeRecipient The address of fee recipient.
    /// @param fee Guardian fee per second in 18 decimal fixed point format.
    /// @return deployed The address of deployed vault.
    function computeAddress(
        bytes32 salt,
        address owner,
        address assetRegistry,
        address guardian,
        address feeRecipient,
        uint256 fee
    ) external view returns (address deployed);
}
