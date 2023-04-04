// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "./IBMerkleOrchard.sol";
import "./IExecution.sol";

/// @title Interface for BalancerExecution module.
interface IBalancerExecution is IExecution {
    // Use struct parameter to avoid stack too deep error.
    /// @param factory Balancer Managed Pool Factory address.
    /// @param name Name of Pool Token.
    /// @param symbol Symbol of Pool Token.
    /// @param poolTokens Initial pool token addresses.
    /// @param weights Token weights.
    /// @param swapFeePercentage Pool swap fee.
    /// @param assetRegistry Asset Registry address.
    /// @param merkleOrchard Balancer Merkle Orchard address.
    /// @param description Simple text describing execution module.
    struct NewBalancerExecutionParams {
        address factory;
        string name;
        string symbol;
        IERC20[] poolTokens;
        uint256[] weights;
        uint256 swapFeePercentage;
        address assetRegistry;
        address merkleOrchard;
        string description;
    }

    /// @notice Initialize Balancer pool and make first deposit.
    /// @dev Need to have a positive allowance for tokens that were provided
    ///      as `poolTokens` to the constructor.
    /// @param vault Address of Aera vault contract.
    function initialize(address vault) external;

    /// @notice Claim Balancer rewards.
    /// @dev It calls claimDistributions() function of Balancer MerkleOrchard.
    ///      Once this function is called, the tokens will be transferred to
    ///      the Vault and it can be distributed via sweep function.
    /// @param claims An array of claims provided as a claim struct.
    ///        See https://docs.balancer.fi/products/merkle-orchard/claiming-tokens#claiming-from-the-contract-directly.
    /// @param tokens An array consisting of tokens to be claimed.
    function claimRewards(
        IBMerkleOrchard.Claim[] memory claims,
        IERC20[] memory tokens
    ) external;

    /// @notice Return the address of vault's asset registry.
    /// @return assetRegistry The address of asset registry.
    function assetRegistry()
        external
        view
        returns (IAssetRegistry assetRegistry);

    /// @notice Return currently listed assets in Balancer pool.
    /// @return assets List of assets.
    function assets() external view returns (IERC20[] memory assets);

    /// @notice Return Balancer Vault.
    function bVault() external view returns (IBVault bVault);

    /// @notice Return address of underlying Balancer Pool
    function pool() external view returns (IBManagedPool pool);

    /// @notice Return Pool ID of underlying Balancer Pool.
    function poolId() external view returns (bytes32 poolId);

    /// @notice Timestamp at when rebalancing ends.
    function rebalanceEndTime()
        external
        view
        returns (uint256 rebalanceEndTime);
}
