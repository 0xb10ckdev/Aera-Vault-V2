// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {TargetSighash} from "../Types.sol";

/// @title IAeraVaultV2Factory
/// @notice Interface for the V2 vault factory.
interface IAeraVaultV2Factory {
    /// @notice Create V2 vault.
    /// @param salt The salt value to create vault.
    /// @param owner Initial owner address.
    /// @param assetRegistry Asset registry address.
    /// @param guardian Guardian address.
    /// @param feeRecipient Fee recipient address.
    /// @param fee Fee accrued per second, denoted in 18 decimal fixed point format.
    /// @param description Vault description.
    /// @return deployed The address of deployed vault.
    function create(
        bytes32 salt,
        address owner,
        address assetRegistry,
        address guardian,
        address feeRecipient,
        uint256 fee,
        string memory description
    ) external returns (address deployed);

    /// @notice Calculate deployment address of V2 vault.
    /// @param salt The salt value to create vault.
    function computeVaultAddress(bytes32 salt)
        external
        view
        returns (address deployed);

    /// @notice Deploy contract with the given bytecode if it is not deployed yet.
    /// @param salt The salt value to create contract.
    /// @param code Bytecode of contract to be deployed.
    function deploy(bytes32 salt, bytes memory code) external;

    /// @notice Calculate deployment address of contract.
    /// @param salt The salt value to create contract.
    /// @param code Bytecode of contract to be deployed.
    function computeAddress(
        bytes32 salt,
        bytes calldata code
    ) external view returns (address);

    /// @notice Returns the address of wrapped native token.
    function wrappedNativeToken() external view returns (address);

    /// @notice Returns vault parameters for vault deployment.
    /// @return owner Initial owner address.
    /// @return assetRegistry Asset registry address.
    /// @return guardian Guardian address.
    /// @return feeRecipient Fee recipient address.
    /// @return fee Fee accrued per second, denoted in 18 decimal fixed point format.
    function parameters()
        external
        view
        returns (
            address owner,
            address assetRegistry,
            address guardian,
            address feeRecipient,
            uint256 fee
        );
}
