// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/IERC20.sol";
import "./IAssetRegistry.sol";
import "./ICustodyEvents.sol";
import "./IHooks.sol";

/// @title Interface for custody module.
interface ICustody is ICustodyEvents {
    /// ERRORS ///

    error Aera__AssetRegistryIsZeroAddress();
    error Aera__AssetRegistryIsNotValid(address assetRegistry);
    error Aera__HooksIsZeroAddress();
    error Aera__HooksIsNotValid(address assetRegistry);
    error Aera__GuardianIsZeroAddress();
    error Aera__GuardianIsOwner();
    error Aera__FeeRecipientIsZeroAddress();
    error Aera__FeeRecipientIsOwner();
    error Aera__FeeIsAboveMax(uint256 actual, uint256 max);
    error Aera__DescriptionIsEmpty();
    error Aera__CallerIsNotGuardian();
    error Aera__AssetIsNotRegistered(IERC20 asset);
    error Aera__AmountExceedsAvailable(
        IERC20 asset, uint256 amount, uint256 available
    );
    error Aera__ExecutionFailed(bytes result);
    error Aera__VaultIsFinalized();
    error Aera__SubmissionFailed(uint256 index, bytes result);
    error Aera__CanNotUseReservedFees();
    error Aera__AssetIsDuplicated(IERC20 asset);
    error Aera__NoAvailableFeeForCaller(address caller);

    /// FUNCTIONS ///

    /// @notice Deposit assets.
    /// @param amounts Struct details for assets and amounts to deposit.
    function deposit(AssetValue[] memory amounts) external;

    /// @notice Withdraw assets.
    /// @param amounts Struct details for assets and amounts to withdraw.
    function withdraw(AssetValue[] memory amounts) external;

    /// @notice Sets current vault guardian and fee recipient.
    /// @param guardian Address of new guardian.
    /// @param feeRecipient Address of new fee recipient.
    function setGuardianAndFeeRecipient(
        address guardian,
        address feeRecipient
    ) external;

    /// @notice Sets current hooks module.
    /// @param hooks Address of new hooks module.
    function setHooks(address hooks) external;

    /// @notice Execute a transaction as the vault.
    /// @dev Execution still should work when vault is finalized.
    ///      For example, it can be used for sweep functionality.
    /// @param operation Struct details for target and calldata to execute.
    function execute(Operation memory operation) external;

    /// @notice Terminate the vault and return all funds to owner.
    function finalize() external;

    /// @notice Stops the guardian from submission.
    function pause() external;

    /// @notice Resumes vault operations.
    function resume() external;

    /// @notice Submit a series of transactions.
    /// @param operations Array of struct details for targets and calldatas to submit.
    function submit(Operation[] memory operations) external;

    /// @notice Claim fees on behalf of guardian.
    function claim() external;

    /// @notice Get the current vault guardian.
    /// @return guardian Address of guardian.
    function guardian() external view returns (address guardian);

    /// @notice Get the current management fee recipient.
    /// @return feeRecipient Address of fee recipient.
    function feeRecipient() external view returns (address feeRecipient);

    /// @notice Get the current asset registry.
    /// @return assetRegistry Address of asset registry.
    function assetRegistry()
        external
        view
        returns (IAssetRegistry assetRegistry);

    /// @notice Get the current hooks module.
    /// @return hooks Address of hooks module.
    function hooks() external view returns (IHooks hooks);

    /// @notice Get guardian fee per second.
    /// @return fee Guardian fee per second in 18 decimal fixed point format.
    function fee() external view returns (uint256 fee);

    /// @notice Get current balances of all assets.
    /// @return assetAmounts Amounts of assets.
    function holdings()
        external
        view
        returns (AssetValue[] memory assetAmounts);

    /// @notice Get current total value of assets in vault.
    /// @return value Current total value.
    function value() external view returns (uint256 value);
}
