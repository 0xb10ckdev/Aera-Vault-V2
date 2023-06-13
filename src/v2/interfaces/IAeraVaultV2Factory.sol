// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

/// @title Interface for v2 vault factory.
interface IAeraVaultV2Factory {
    /// @notice Create v2 vault.
    /// @param assetRegistry The address of asset registry.
    /// @param execution The address of execution module.
    /// @param guardian The address of guardian.
    /// @param feeRecipient The address of fee recipient.
    /// @param guardianFee Guardian fee per second in 18 decimal fixed point format.
    /// @param minThreshold Minimum action threshold for erc20 assets measured
    ///                     in base token terms.
    /// @param minYieldActionThreshold Minimum action threshold for yield bearing assets
    ///                                measured in base token terms.
    function create(
        address assetRegistry,
        address execution,
        address guardian,
        address feeRecipient,
        uint256 guardianFee,
        uint256 minThreshold,
        uint256 minYieldActionThreshold
    ) external;
}
