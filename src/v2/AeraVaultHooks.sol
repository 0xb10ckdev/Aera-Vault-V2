// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/IERC20.sol";
import "@openzeppelin/ERC165.sol";
import "@openzeppelin/ERC165Checker.sol";
import "@openzeppelin/Ownable2Step.sol";
import "@openzeppelin/SafeERC20.sol";
import "@openzeppelin/IERC20IncreaseAllowance.sol";
import "./interfaces/IHooks.sol";
import "./interfaces/IVault.sol";
import "./TargetSighashLib.sol";
import "./Types.sol";
import {ONE} from "./Constants.sol";

/// @title AeraVaultHooks
/// @notice Default hooks contract which implements several safeguards.
/// @dev Connected vault MUST only call submit with tokens that can increase allowances with approve and increaseAllowance.
contract AeraVaultHooks is IHooks, ERC165, Ownable2Step {
    using SafeERC20 for IERC20;

    /// STORAGE ///

    /// @notice The address of the vault.
    address public vault;

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
    mapping(TargetSighash => bool) internal _targetSighashAllowed;

    /// @notice Total value of assets in vault before submission.
    /// @dev Assigned in `beforeSubmit` and used in `afterSubmit`.
    uint256 internal _beforeValue;

    /// @notice ETH amount in vault before submission.
    uint256 internal _beforeBalance;

    /// ERRORS ///

    error Aera__CallerIsNotVault();
    error Aera__VaultIsZeroAddress();
    error Aera__ETHBalanceIsDecreased();
    error Aera__MaxDailyExecutionLossIsGreaterThanOne();
    error Aera__NoCodeAtTarget(address target);
    error Aera__VaultIsNotValid(address vault);
    error Aera__CallIsNotAllowed(Operation operation);
    error Aera__ExceedsMaxDailyExecutionLoss();
    error Aera__AllowanceIsNotZero(address asset, address spender);
    error Aera__HooksInitialOwnerIsZeroAddress();
    error Aera__RemovingNonexistentTargetSighash(TargetSighash targetSighash);

    /// MODIFIERS ///

    /// @dev Throws if called by any account other than the vault.
    modifier onlyVault() {
        if (msg.sender != vault) {
            revert Aera__CallerIsNotVault();
        }
        _;
    }

    /// FUNCTIONS ///

    /// @param owner_ Initial owner address.
    /// @param vault_ Vault address.
    /// @param maxDailyExecutionLoss_ The fraction of value that the vault can
    ///                               lose per day in the course of submissions.
    /// @param targetSighashAllowlist Array of target contract and sighash combinations to allow.
    constructor(
        address owner_,
        address vault_,
        uint256 maxDailyExecutionLoss_,
        TargetSighashData[] memory targetSighashAllowlist
    ) Ownable() {
        // Requirements: validate vault.
        if (vault_ == address(0)) {
            revert Aera__VaultIsZeroAddress();
        }
        if (owner_ == address(0)) {
            revert Aera__HooksInitialOwnerIsZeroAddress();
        }

        // Requirements: check if max daily execution loss is bounded.
        if (maxDailyExecutionLoss_ > ONE) {
            revert Aera__MaxDailyExecutionLossIsGreaterThanOne();
        }

        uint256 numTargetSighashAllowlist = targetSighashAllowlist.length;

        // Effects: initialize target sighash allowlist.
        TargetSighashData memory targetSighash;
        for (uint256 i = 0; i < numTargetSighashAllowlist;) {
            targetSighash = targetSighashAllowlist[i];
            _targetSighashAllowed[TargetSighashLib.toTargetSighash(
                targetSighash.target, targetSighash.selector
            )] = true;
            unchecked {
                i++; // gas savings
            }
        }

        // Effects: initialize state variables.
        vault = vault_;
        maxDailyExecutionLoss = maxDailyExecutionLoss_;
        currentDay = block.timestamp / 1 days;
        cumulativeDailyMultiplier = ONE;

        // Effects: set new owner.
        _transferOwnership(owner_);
    }

    /// @notice Add targetSighash pair to allowlist.
    /// @param target Address of target.
    /// @param selector Selector of function.
    function addTargetSighash(
        address target,
        bytes4 selector
    ) external onlyOwner {
        // Requirements: check there is code at target.
        if (target.code.length == 0) {
            revert Aera__NoCodeAtTarget(target);
        }

        // Effects: add target sighash combination to the allowlist.
        _targetSighashAllowed[TargetSighashLib.toTargetSighash(
            target, selector
        )] = true;

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
        TargetSighash targetSighash = TargetSighashLib.toTargetSighash(target, selector);

        // Requirements: check that current target sighash is set.
        if (!_targetSighashAllowed[targetSighash]) {
            revert Aera__RemovingNonexistentTargetSighash(targetSighash);
        }

        // Effects: remove target sighash combination from the allowlist.
        delete _targetSighashAllowed[targetSighash];

        // Log the removal.
        emit TargetSighashRemoved(target, selector);
    }

    /// @inheritdoc IHooks
    function beforeDeposit(AssetValue[] memory amounts)
        external
        override
        onlyVault
    {}

    /// @inheritdoc IHooks
    function afterDeposit(AssetValue[] memory amounts)
        external
        override
        onlyVault
    {}

    /// @inheritdoc IHooks
    function beforeWithdraw(AssetValue[] memory amounts)
        external
        override
        onlyVault
    {}

    /// @inheritdoc IHooks
    function afterWithdraw(AssetValue[] memory amounts)
        external
        override
        onlyVault
    {}

    /// @inheritdoc IHooks
    function beforeSubmit(Operation[] calldata operations)
        external
        override
        onlyVault
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
            if (!_targetSighashAllowed[sigHash]) {
                revert Aera__CallIsNotAllowed(operations[i]);
            }

            unchecked {
                i++;
            } // gas savings
        }

        // Effects: remember current vault value and ETH balance for use in afterSubmit.
        _beforeValue = IVault(vault).value();
        _beforeBalance = vault.balance;
    }

    /// @inheritdoc IHooks
    function afterSubmit(Operation[] calldata operations)
        external
        override
        onlyVault
    {
        uint256 day = block.timestamp / 1 days;

        if (vault.balance < _beforeBalance) {
            revert Aera__ETHBalanceIsDecreased();
        }

        if (_beforeValue > 0) {
            // Initialize new cumulative multiplier with the current submit multiplier.
            uint256 newMultiplier =
                (currentDay == day ? cumulativeDailyMultiplier : ONE);
            newMultiplier =
                newMultiplier * IVault(vault).value() / _beforeValue;

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
                if (token.allowance(vault, spender) > 0) {
                    revert Aera__AllowanceIsNotZero(address(token), spender);
                }
            }
            unchecked {
                i++;
            } // gas savings
        }
    }

    /// @inheritdoc IHooks
    function beforeFinalize() external override onlyVault {}

    /// @inheritdoc IHooks
    function afterFinalize() external override onlyVault {
        // Effects: release storage
        maxDailyExecutionLoss = 0;
        currentDay = 0;
        cumulativeDailyMultiplier = 0;
    }

    /// @inheritdoc IHooks
    function decommission() external override onlyVault {
        // Effects: reset vault address.
        vault = address(0);

        // Effects: release storage
        maxDailyExecutionLoss = 0;
        currentDay = 0;
        cumulativeDailyMultiplier = 0;

        // Log decommissioning.
        emit Decommissioned();
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

    /// @notice Check whether target and sighash combination is allowed.
    /// @param key Struct containing target contract and sighash.
    function targetSighashAllowed(TargetSighashData calldata key)
        public
        view
        returns (bool)
    {
        return _targetSighashAllowed[TargetSighashLib.toTargetSighash(
            key.target, key.selector
        )];
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
