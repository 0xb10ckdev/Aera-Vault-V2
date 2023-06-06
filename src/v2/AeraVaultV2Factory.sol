// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/Ownable.sol";
import "./interfaces/IAeraVaultV2Factory.sol";
import "./AeraVaultV2.sol";

/// @title Aera Vault V2 Factory contract.
contract AeraVaultV2Factory is IAeraVaultV2Factory, Ownable {
    /// EVENTS ///

    /// @notice Emitted when the vault is created.
    /// @param vault Vault address.
    /// @param assetRegistry The address of asset registry.
    /// @param execution The address of execution module.
    /// @param guardian The address of guardian.
    /// @param feeRecipient The address of fee recipient.
    /// @param guardianFee Guardian fee per second in 18 decimal fixed point format.
    /// @param minThreshold Minimum action threshold for erc20 assets measured
    ///                     in base token terms.
    /// @param minYieldActionThreshold Minimum action threshold for yield bearing assets
    ///                                measured in base token terms.
    event VaultCreated(
        address vault,
        address assetRegistry,
        address execution,
        address guardian,
        address feeRecipient,
        uint256 guardianFee,
        uint256 minThreshold,
        uint256 minYieldActionThreshold
    );

    /// FUNCTIONS ///

    /// @inheritdoc IAeraVaultV2Factory
    function create(
        address assetRegistry,
        address execution,
        address guardian,
        address feeRecipient,
        uint256 guardianFee,
        uint256 minThreshold,
        uint256 minYieldActionThreshold
    ) external override onlyOwner {
        AeraVaultV2 vault = new AeraVaultV2(
            assetRegistry,
            execution,
            guardian,
            feeRecipient,
            guardianFee,
            minThreshold,
            minYieldActionThreshold
        );
        vault.transferOwnership(msg.sender);

        emit VaultCreated(
            address(vault),
            assetRegistry,
            execution,
            guardian,
            feeRecipient,
            guardianFee,
            minThreshold,
            minYieldActionThreshold
        );
    }
}
