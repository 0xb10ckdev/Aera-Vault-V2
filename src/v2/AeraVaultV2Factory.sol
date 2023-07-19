// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/Ownable.sol";
import "./interfaces/IAeraVaultV2Factory.sol";

/// @title Aera Vault V2 Factory contract.
contract AeraVaultV2Factory is IAeraVaultV2Factory, Ownable {
    /// EVENTS ///

    /// @notice Emitted when the vault is created.
    /// @param vault Vault address.
    /// @param assetRegistry The address of asset registry.
    /// @param guardian The address of guardian.
    /// @param feeRecipient The address of fee recipient.
    /// @param fee Guardian fee per second in 18 decimal fixed point format.
    event VaultCreated(
        address vault,
        address assetRegistry,
        address guardian,
        address feeRecipient,
        uint256 fee
    );

    /// FUNCTIONS ///

    /// @inheritdoc IAeraVaultV2Factory
    function create(
        address assetRegistry,
        address guardian,
        address feeRecipient,
        uint256 fee
    ) external override onlyOwner returns (AeraVaultV2 vault) {
        vault = new AeraVaultV2(
            assetRegistry,
            guardian,
            feeRecipient,
            fee
        );

        vault.transferOwnership(msg.sender);

        emit VaultCreated(
            address(vault), assetRegistry, guardian, feeRecipient, fee
        );
    }
}
