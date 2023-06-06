// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/IERC20.sol";
import "./IAssetRegistry.sol";
import "./ICustodyEvents.sol";
import "./IExecution.sol";
import "./ISweepable.sol";

/// @title Interface for custody module.
interface ICustody is ICustodyEvents, ISweepable {
    /// TYPES ///

    /// @param asset Address of asset.
    /// @param value Value of asset.
    struct AssetValue {
        IERC20 asset;
        uint256 value;
    }

    /// ERRORS ///

    error Aera__AssetRegistryIsZeroAddress();
    error Aera__AssetRegistryIsNotValid(address assetRegistry);
    error Aera__ExecutionIsZeroAddress();
    error Aera__ExecutionIsNotValid(address execution);
    error Aera__GuardianIsZeroAddress();
    error Aera__GuardianIsOwner();
    error Aera__FeeRecipientIsZeroAddress();
    error Aera__FeeRecipientIsOwner();
    error Aera__GuardianFeeIsAboveMax(uint256 actual, uint256 max);
    error Aera__CallerIsNotGuardian();
    error Aera__CallerIsNotOwnerOrGuardian();
    error Aera__AssetIsNotRegistered(IERC20 asset);
    error Aera__AmountExceedsAvailable(
        IERC20 asset,
        uint256 amount,
        uint256 available
    );
    error Aera__VaultIsFinalized();
    error Aera__ValueLengthIsNotSame(uint256 numAssets, uint256 numValues);
    error Aera__SumOfWeightsIsNotOne();
    error Aera__AssetIsDuplicated(IERC20 asset);
    error Aera__RebalancingHasNotStarted();
    error Aera__RebalancingIsOnGoing(uint256 endTime);
    error Aera__NoAvailableFeeForCaller(address caller);
    error Aera__CannotSweepRegisteredAsset();

    /// FUNCTIONS ///

    /// @notice Deposit assets.
    /// @param amounts Struct details for assets and amounts to deposit.
    function deposit(AssetValue[] memory amounts) external;

    /// @notice Withdraw assets.
    /// @param amounts Struct details for assets and amounts to withdraw.
    /// @param force Whether it can touch assets inside execution module or not.
    function withdraw(AssetValue[] memory amounts, bool force) external;

    /// @notice Sets current vault guardian and fee recipient.
    /// @param guardian Address of new guardian.
    /// @param feeRecipient Address of new fee recipient.
    function setGuardian(address guardian, address feeRecipient) external;

    /// @notice Sets current asset registry.
    /// @param assetRegistry Address of new asset registry.
    function setAssetRegistry(address assetRegistry) external;

    /// @notice Sets current execution module.
    /// @param execution Address of new execution module.
    function setExecution(address execution) external;

    /// @notice Terminate the vault and return all funds to owner.
    function finalize() external;

    /// @notice Ends rebalancing and stops the guardian from initiating new rebalances.
    function pauseVault() external;

    /// @notice Resumes vault operations.
    function unpauseVault() external;

    /// @notice Initiate weight change of assets in the custody module
    ///         to a target distribution.
    /// @param assetWeights Struct details for assets and their weights.
    /// @param startTime Timestamp by which weight movement should start.
    /// @param endTime Timestamp by which the weights should reach target values.
    function startRebalance(
        AssetValue[] memory assetWeights,
        uint256 startTime,
        uint256 endTime
    ) external;

    /// @notice Formally end current rebalance and retrieve funds from execution module.
    function endRebalance() external;

    /// @notice Terminate rebalance early and retrieve funds from execution module.
    function endRebalanceEarly() external;

    /// @notice Claim fees on behalf of guardian.
    function claimGuardianFees() external;

    /// @notice Get the current vault guardian.
    /// @return guardian Address of guardian.
    function guardian() external view returns (address guardian);

    /// @notice Get the current management fee recipient.
    /// @return feeRecipient Address of fee recipient.
    function feeRecipient() external view returns (address feeRecipient);

    /// @notice Get the current execution module.
    /// @return execution Address of execution module.
    function execution() external view returns (IExecution execution);

    /// @notice Get the current asset registry.
    /// @return assetRegistry Address of asset registry.
    function assetRegistry()
        external
        view
        returns (IAssetRegistry assetRegistry);

    /// @notice Get current balances of all assets.
    /// @param assetAmounts Amounts of assets.
    function holdings()
        external
        view
        returns (AssetValue[] memory assetAmounts);

    /// @notice Get guardian fee per second.
    /// @param guardianFee Guardian fee per second in 18 decimal fixed point format.
    function guardianFee() external view returns (uint256 guardianFee);

    /// @notice Timestamp at when rebalancing ends.
    function rebalanceEndTime()
        external
        view
        returns (uint256 rebalanceEndTime);
}
