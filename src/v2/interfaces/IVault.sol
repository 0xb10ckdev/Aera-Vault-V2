// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/IERC20.sol";
import "./IAssetRegistry.sol";
import "./IVaultEvents.sol";
import "./IHooks.sol";

/// @title IVault
/// @notice Interface for the vault module.
/// @dev Any implementation MUST also implement Ownable2Step.
interface IVault is IVaultEvents {
    /// ERRORS ///

    error Aera__AssetRegistryIsZeroAddress();
    error Aera__AssetRegistryIsNotValid(address assetRegistry);
    error Aera__AssetRegistryHasInvalidVault();
    error Aera__HooksIsZeroAddress();
    error Aera__HooksIsNotValid(address hooks);
    error Aera__HooksHasInvalidVault();
    error Aera__GuardianIsZeroAddress();
    error Aera__GuardianIsOwner();
    error Aera__InitialOwnerIsZeroAddress();
    error Aera__FeeRecipientIsZeroAddress();
    error Aera__ExecuteTargetIsHooksAddress();
    error Aera__SubmitTransfersAssetFromOwner();
    error Aera__SubmitTargetIsHooksAddress();
    error Aera__FeeRecipientIsOwner();
    error Aera__FeeIsAboveMax(uint256 actual, uint256 max);
    error Aera__DescriptionIsEmpty();
    error Aera__CallerIsNotOwnerAndGuardian();
    error Aera__CallerIsNotGuardian();
    error Aera__AssetIsNotRegistered(IERC20 asset);
    error Aera__AmountExceedsAvailable(
        IERC20 asset, uint256 amount, uint256 available
    );
    error Aera__ExecutionFailed(bytes result);
    error Aera__VaultIsFinalized();
    error Aera__SubmissionFailed(uint256 index, bytes result);
    error Aera__CannotUseReservedFees();
    error Aera__AssetIsDuplicated(IERC20 asset);
    error Aera__NoClaimableFeesForCaller(address caller);
    error Aera__WrappedNativeTokenIsZeroAddress();
    error Aera__NotWrappedNativeTokenContract();
    error Aera__CannotRenounceOwnership();

    /// FUNCTIONS ///

    /// @notice Deposit assets.
    /// @param amounts Assets and amounts to deposit.
    /// @dev MUST revert if not called by owner.
    function deposit(AssetValue[] memory amounts) external;

    /// @notice Withdraw assets.
    /// @param amounts Assets and amounts to withdraw.
    /// @dev MUST revert if not called by owner.
    function withdraw(AssetValue[] memory amounts) external;

    /// @notice Set current guardian and fee recipient.
    /// @param guardian New guardian address.
    /// @param feeRecipient New fee recipient address.
    /// @dev MUST revert if not called by owner.
    function setGuardianAndFeeRecipient(
        address guardian,
        address feeRecipient
    ) external;

    /// @notice Sets the current hooks module.
    /// @param hooks New hooks module address.
    /// @dev MUST revert if not called by owner.
    function setHooks(address hooks) external;

    /// @notice Execute a transaction via the vault module.
    /// @dev Execution still should work when vault module is finalized.
    /// @param operation Struct details for target and calldata to execute.
    /// @dev MUST revert if not called by owner.
    function execute(Operation memory operation) external;

    /// @notice Terminate the vault module and return all funds to owner.
    /// @dev MUST revert if not called by owner.
    function finalize() external;

    /// @notice Stops the guardian from submission and halts fee accrual.
    /// @dev MUST revert if not called by owner or guardian.
    function pause() external;

    /// @notice Resume fee accrual and guardian submissions.
    /// @dev MUST revert if not called by owner.
    function resume() external;

    /// @notice Submit a series of transactions for execution via the vault module.
    /// @param operations Sequence of operations to execute.
    /// @dev MUST revert if not called by guardian.
    function submit(Operation[] memory operations) external;

    /// @notice Claim fees on behalf of a current or previous fee recipient.
    function claim() external;

    /// @notice Get the current guardian.
    /// @return guardian Address of guardian.
    function guardian() external view returns (address guardian);

    /// @notice Get the current fee recipient.
    /// @return feeRecipient Address of fee recipient.
    function feeRecipient() external view returns (address feeRecipient);

    /// @notice Get the current asset registry.
    /// @return assetRegistry Address of asset registry.
    function assetRegistry()
        external
        view
        returns (IAssetRegistry assetRegistry);

    /// @notice Get the current hooks module address.
    /// @return hooks Address of hooks module.
    function hooks() external view returns (IHooks hooks);

    /// @notice Get fee per second.
    /// @return fee Fee per second in 18 decimal fixed point format.
    function fee() external view returns (uint256 fee);

    /// @notice Get current balances of all assets.
    /// @return assetAmounts Amounts of registered assets.
    function holdings()
        external
        view
        returns (AssetValue[] memory assetAmounts);

    /// @notice Get current total value of assets in vault module.
    /// @return value Current total value.
    function value() external view returns (uint256 value);
}
