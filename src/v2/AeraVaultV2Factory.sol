// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/Create2.sol";
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
        bytes32 salt,
        address owner,
        address assetRegistry,
        address guardian,
        address feeRecipient,
        uint256 fee
    ) external override onlyOwner returns (address deployed) {
        bytes memory bytecode = abi.encodePacked(
            type(AeraVaultV2).creationCode,
            abi.encode(owner, assetRegistry, guardian, feeRecipient, fee)
        );

        Create2.deploy(0, salt, bytecode);

        deployed = Create2.computeAddress(salt, keccak256(bytecode));

        emit VaultCreated(deployed, assetRegistry, guardian, feeRecipient, fee);
    }

    /// @inheritdoc IAeraVaultV2Factory
    function computeAddress(
        bytes32 salt,
        address owner,
        address assetRegistry,
        address guardian,
        address feeRecipient,
        uint256 fee
    ) external view override returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(AeraVaultV2).creationCode,
            abi.encode(owner, assetRegistry, guardian, feeRecipient, fee)
        );

        return Create2.computeAddress(salt, keccak256(bytecode));
    }
}
