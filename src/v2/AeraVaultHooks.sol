// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/IERC20.sol";
import "@openzeppelin/ERC165.sol";
import "@openzeppelin/ERC165Checker.sol";
import "@openzeppelin/Ownable2Step.sol";
import "@openzeppelin/SafeERC20.sol";
import "@openzeppelin/IERC20IncreaseAllowance.sol";
import "./interfaces/IHooks.sol";
import "./interfaces/ICustody.sol";
import "./TargetSighashLib.sol";
import {ONE} from "./Constants.sol";

/// @title AeraVaultHooks
/// @notice Default hooks contract which implements several safeguards.
/// @dev Connected custody module MUST only call submit with tokens that can increase allowances with approve and increaseAllowance.
contract AeraVaultHooks is IHooks, ERC165, Ownable2Step {
    using SafeERC20 for IERC20;

    /// @notice The address of the custody module.
    address public immutable custody;

    /// STORAGE ///

    /// @notice The maximum fraction of value that the vault can lose per day
    ///         during submit transactions.
    ///         e.g. 0.1 (in 18-decimal form) allows the vault to lose up to
    ///         10% in value across consecutive submissions.
    uint256 public maxDailyExecutionLoss;

    /// @notice Current day (UTC).
    uint256 public currentDay;

    /// @notice Accumulated value multiplier during submit transactions.
    uint256 public cumulativeDailyMultiplier;

    /// @notice Allowed target contract and sighash combinations.
    mapping(TargetSighash => bool) public targetSighashAllowed;

    /// @notice Total value of assets in vault before submission.
    /// @dev Assigned in `beforeSubmit` and used in `afterSubmit`.
    uint256 internal _beforeValue;

    /// @notice ETH amount in vault before submission.
    uint256 internal _beforeBalance;

    /// ERRORS ///

    error Aera__CallerIsNotCustody();
    error Aera__CustodyIsZeroAddress();
    error Aera__ETHBalanceIsDecreased();
    error Aera__MaxDailyExecutionLossIsGreaterThanOne();
    error Aera__CustodyIsNotValid(address custody);
    error Aera__CallIsNotAllowed(Operation operation);
    error Aera__ExceedsMaxDailyExecutionLoss();
    error Aera__AllowanceIsNotZero(address asset, address spender);
    error Aera__HooksInitialOwnerIsZeroAddress();

    /// MODIFIERS ///

    /// @dev Throws if called by any account other than the custody module.
    modifier onlyCustody() {
        if (msg.sender != custody) {
            revert Aera__CallerIsNotCustody();
        }
        _;
    }

    /// FUNCTIONS ///

    /// @param owner_ Initial owner address.
    /// @param custody_ Custody module address.
    /// @param maxDailyExecutionLoss_ The fraction of value that the vault can
    ///                               lose per day in the course of submissions.
    /// @param targetSighashAllowlist Array of target contract and sighash combinations to allow.
    constructor(
        address owner_,
        address custody_,
        uint256 maxDailyExecutionLoss_,
        TargetSighash[] memory targetSighashAllowlist
    ) {
        // Requirements: validate custody module.
        if (custody_ == address(0)) {
            revert Aera__CustodyIsZeroAddress();
        }
        if (owner_ == address(0)) {
            revert Aera__HooksInitialOwnerIsZeroAddress();
        }
        if (
            !ERC165Checker.supportsInterface(
                custody_, type(ICustody).interfaceId
            )
        ) {
            revert Aera__CustodyIsNotValid(custody_);
        }

        // Requirements: check if max daily execution loss is bounded.
        if (maxDailyExecutionLoss_ > ONE) {
            revert Aera__MaxDailyExecutionLossIsGreaterThanOne();
        }

        uint256 numTargetSighashAllowlist = targetSighashAllowlist.length;

        // Effects: initialize target sighash allowlist.
        for (uint256 i = 0; i < numTargetSighashAllowlist;) {
            targetSighashAllowed[targetSighashAllowlist[i]] = true;
            unchecked {
                i++; // gas savings
            }
        }

        // Effects: initialize state variables.
        custody = custody_;
        maxDailyExecutionLoss = maxDailyExecutionLoss_;
        currentDay = block.timestamp / 1 days;
        cumulativeDailyMultiplier = ONE;

        // Effects: create a pending ownership transfer.
        _transferOwnership(owner_);
    }

    /// @notice Add targetSighash pair to allowlist.
    /// @param target Address of target.
    /// @param selector Selector of function.
    function addTargetSighash(
        address target,
        bytes4 selector
    ) external onlyOwner {
        // Effects: add target sighash combination to the allowlist.
        targetSighashAllowed[TargetSighashLib.toTargetSighash(target, selector)]
        = true;

        // Log the addition.
        emit TargetSighashAdded(target, selector);
    }

    /// @notice Remove targetSighash pair from allowlist.
    /// @param target Address of target.
    /// @param selector Selector of function.
    function removeTargetSighash(
        address target,
        bytes4 selector
    ) external onlyOwner {
        // Effects: remove target sighash combination from the allowlist.
        delete targetSighashAllowed[
            TargetSighashLib.toTargetSighash(target, selector)
        ];

        // Log the removal.
        emit TargetSighashRemoved(target, selector);
    }

    /// @inheritdoc IHooks
    function beforeDeposit(AssetValue[] memory amounts)
        external
        override
        onlyCustody
    {}

    /// @inheritdoc IHooks
    function afterDeposit(AssetValue[] memory amounts)
        external
        override
        onlyCustody
    {}

    /// @inheritdoc IHooks
    function beforeWithdraw(AssetValue[] memory amounts)
        external
        override
        onlyCustody
    {}

    /// @inheritdoc IHooks
    function afterWithdraw(AssetValue[] memory amounts)
        external
        override
        onlyCustody
    {}

    /// @inheritdoc IHooks
    function beforeSubmit(Operation[] calldata operations)
        external
        override
        onlyCustody
    {
        uint256 numOperations = operations.length;
        bytes4 selector;

        // Requirements: validate that all operations are allowed.
        for (uint256 i = 0; i < numOperations;) {
            selector = bytes4(operations[i].data[0:4]);

            TargetSighash sigHash = TargetSighashLib.toTargetSighash(
                operations[i].target, selector
            );

            // Requirements: validate that the target sighash combination is allowed.
            if (!targetSighashAllowed[sigHash]) {
                revert Aera__CallIsNotAllowed(operations[i]);
            }

            unchecked {
                i++;
            } // gas savings
        }

        // Effects: remember current vault value and ETH balance for use in afterSubmit.
        _beforeValue = ICustody(custody).value();
        _beforeBalance = custody.balance;
    }

    /// @inheritdoc IHooks
    function afterSubmit(Operation[] calldata operations)
        external
        override
        onlyCustody
    {
        uint256 day = block.timestamp / 1 days;

        if (custody.balance < _beforeBalance) {
            revert Aera__ETHBalanceIsDecreased();
        }

        if (_beforeValue > 0) {
            // Initialize new cumulative multiplier with the current submit multiplier.
            uint256 newMultiplier =
                (ICustody(custody).value() * ONE) / _beforeValue;

            if (currentDay == day) {
                // Calculate total multiplier for today.
                newMultiplier =
                    (cumulativeDailyMultiplier * newMultiplier) / ONE;
            }

            // Requirements: check that daily execution loss is within bounds.
            if (newMultiplier < ONE - maxDailyExecutionLoss) {
                revert Aera__ExceedsMaxDailyExecutionLoss();
            }

            // Effects: update the daily multiplier.
            cumulativeDailyMultiplier = newMultiplier;
        }

        // Effects: reset day and prior vault value for the next submission.
        currentDay = day;
        _beforeBalance = 0;
        _beforeValue = 0;

        uint256 numOperations = operations.length;
        bytes4 selector;
        address spender;
        uint256 amount;
        IERC20 token;

        // Requirements: check that there are no outgoing allowances that were introduced.
        for (uint256 i = 0; i < numOperations;) {
            selector = bytes4(operations[i].data[0:4]);
            if (_isAllowanceSelector(selector)) {
                // Extract spender and amount from the allowance transaction.
                (spender, amount) =
                    abi.decode(operations[i].data[4:], (address, uint256));

                // If amount is 0 then allowance hasn't been increased.
                if (amount == 0) {
                    unchecked {
                        i++;
                    } // gas savings
                    continue;
                }

                token = IERC20(operations[i].target);

                // Requirements: check that the current outgoing allowance for this token is zero.
                if (token.allowance(custody, spender) > 0) {
                    revert Aera__AllowanceIsNotZero(address(token), spender);
                }
            }
            unchecked {
                i++;
            } // gas savings
        }
    }

    /// @inheritdoc IHooks
    function beforeFinalize() external override onlyCustody {}

    /// @inheritdoc IHooks
    function afterFinalize() external override onlyCustody {
        // Effects: release storage
        maxDailyExecutionLoss = 0;
        currentDay = 0;
        cumulativeDailyMultiplier = 0;
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return interfaceId == type(IHooks).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// INTERNAL FUNCTIONS ///

    /// @notice Check whether selector is allowance related selector or not.
    /// @param selector Selector of calldata to check.
    /// @return isAllowanceSelector True if selector is allowance related selector.
    function _isAllowanceSelector(bytes4 selector)
        internal
        pure
        returns (bool isAllowanceSelector)
    {
        return selector == IERC20.approve.selector
            || selector == IERC20IncreaseAllowance.increaseAllowance.selector;
    }
}
