// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/Ownable.sol";
import "./interfaces/IAeraVaultV2Factory.sol";
import "./AeraVaultHooks.sol";
import "./AeraVaultV2.sol";

/// @title Aera Vault V2 Factory contract.
contract AeraVaultV2Factory is IAeraVaultV2Factory, Ownable {
    /// EVENTS ///

    /// @notice Emitted when the vault is created.
    /// @param vault Vault address.
    /// @param hooks Hooks address.
    /// @param assetRegistry The address of asset registry.
    /// @param guardian The address of guardian.
    /// @param feeRecipient The address of fee recipient.
    /// @param fee Guardian fee per second in 18 decimal fixed point format.
    /// @param maxDailyExecutionLoss  The fraction of value that the vault can
    ///                                lose per day in the course of submissions.
    /// @param targetSighashAllowlist Array of target sighash to allow.
    event VaultCreated(
        address vault,
        address hooks,
        address assetRegistry,
        address guardian,
        address feeRecipient,
        uint256 fee,
        uint256 maxDailyExecutionLoss,
        TargetSighash[] targetSighashAllowlist
    );

    /// FUNCTIONS ///

    /// @inheritdoc IAeraVaultV2Factory
    function create(
        address assetRegistry,
        address guardian,
        address feeRecipient,
        uint256 fee,
        uint256 maxDailyExecutionLoss,
        TargetSighash[] memory targetSighashAllowlist
    ) external override onlyOwner {
        AeraVaultV2 vault = new AeraVaultV2(
            assetRegistry,
            guardian,
            feeRecipient,
            fee
        );

        AeraVaultHooks hooks =
        new AeraVaultHooks(address(vault), maxDailyExecutionLoss, targetSighashAllowlist);

        vault.setHooks(address(hooks));

        vault.transferOwnership(msg.sender);
        hooks.transferOwnership(msg.sender);

        emit VaultCreated(
            address(vault),
            address(hooks),
            assetRegistry,
            guardian,
            feeRecipient,
            fee,
            maxDailyExecutionLoss,
            targetSighashAllowlist
        );
    }
}
