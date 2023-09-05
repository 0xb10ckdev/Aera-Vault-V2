// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {
    TargetSighash,
    AssetRegistryParameters,
    HooksParameters
} from "../Types.sol";

/// @title IAeraV2Factory
/// @notice Interface for the V2 vault factory.
interface IAeraV2Factory {
    /// @notice Create V2 vault.
    /// @param salt The salt value to create vault.
    /// @param owner Initial owner address.
    /// @param guardian Guardian address.
    /// @param feeRecipient Fee recipient address.
    /// @param fee Fee accrued per second, denoted in 18 decimal fixed point format.
    /// @param description Vault description.
    /// @param assetRegistryParameters Struct details for asset registry deployment.
    /// @param hooksParameters Struct details for hooks deployment.
    /// @return deployedVault The address of deployed vault.
    /// @return deployedAssetRegistry The address of deployed asset registry.
    /// @return deployedHooks The address of deployed hooks.
    function create(
        bytes32 salt,
        address owner,
        address guardian,
        address feeRecipient,
        uint256 fee,
        string calldata description,
        AssetRegistryParameters memory assetRegistryParameters,
        HooksParameters memory hooksParameters
    )
        external
        returns (
            address deployedVault,
            address deployedAssetRegistry,
            address deployedHooks
        );

    /// @notice Calculate deployment address of V2 vault.
    /// @param salt The salt value to create vault.
    function computeVaultAddress(bytes32 salt)
        external
        view
        returns (address deployed);

    /// @notice Returns the address of wrapped native token.
    function wrappedNativeToken() external view returns (address);

    /// @notice Returns vault parameters for vault deployment.
    /// @return owner Initial owner address.
    /// @return assetRegistry Asset registry address.
    /// @return hooks Hooks address.
    /// @return guardian Guardian address.
    /// @return feeRecipient Fee recipient address.
    /// @return fee Fee accrued per second, denoted in 18 decimal fixed point format.
    function parameters()
        external
        view
        returns (
            address owner,
            address assetRegistry,
            address hooks,
            address guardian,
            address feeRecipient,
            uint256 fee
        );
}
