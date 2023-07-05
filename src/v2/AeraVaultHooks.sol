// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/ERC165.sol";
import "@openzeppelin/ERC165Checker.sol";
import "@openzeppelin/Ownable.sol";
import "@openzeppelin/SafeERC20.sol";
import "./interfaces/IHooks.sol";
import "./interfaces/ICustody.sol";
import "./TargetSighashLib.sol";
import {ONE} from "./Constants.sol";

/// @title Aera Vault Hooks contract.
contract AeraVaultHooks is IHooks, ERC165, Ownable {
    using SafeERC20 for IERC20;

    bytes4 internal constant _APPROVE_SELECTOR =
        bytes4(keccak256("approve(address,uint256)"));

    bytes4 internal constant _INCREASE_ALLOWANCE_SELECTOR =
        bytes4(keccak256("increaseAllowance(address,uint256)"));

    /// @notice The address of the custody module.
    ICustody public immutable custody;

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

    /// @notice Allowed target and sighash combinations.
    mapping(TargetSighash => bool) public targetSighashAllowed;

    /// @notice Total value of assets in vault before submission.
    uint256 internal _beforeValue;

    /// MODIFIERS ///

    /// @dev Throws if called by any account other than the custody module.
    modifier onlyCustody() {
        if (msg.sender != address(custody)) {
            revert Aera__CallerIsNotCustody();
        }
        _;
    }

    /// FUNCTIONS ///

    /// @notice Initialize the hooks contract by providing references to
    ///         custody module and other parameters.
    /// @param custody_ The address of custody module.
    /// @param maxDailyExecutionLoss_  The fraction of value that the vault can
    ///                                lose per day in the course of submissions.
    /// @param targetSighashAllowlist Array of target sighash to allow.
    constructor(
        address custody_,
        uint256 maxDailyExecutionLoss_,
        TargetSighash[] memory targetSighashAllowlist
    ) {
        if (custody_ == address(0)) {
            revert Aera__CustodyIsZeroAddress();
        }
        if (
            !ERC165Checker.supportsInterface(
                custody_, type(ICustody).interfaceId
            )
        ) {
            revert Aera__CustodyIsNotValid(custody_);
        }

        uint256 numTargetSighashAllowlist = targetSighashAllowlist.length;

        for (uint256 i = 0; i < numTargetSighashAllowlist; i++) {
            targetSighashAllowed[targetSighashAllowlist[i]] = true;
        }

        custody = ICustody(custody_);
        maxDailyExecutionLoss = maxDailyExecutionLoss_;
        currentDay = block.timestamp / 1 days;
        cumulativeDailyMultiplier = ONE;
    }

    /// @inheritdoc IHooks
    function addTargetSighash(
        address target,
        bytes4 selector
    ) external override onlyOwner {
        targetSighashAllowed[TargetSighashLib.toTargetSighash(target, selector)]
        = true;

        emit AddTargetSighash(target, selector);
    }

    /// @inheritdoc IHooks
    function removeTargetSighash(
        address target,
        bytes4 selector
    ) external override onlyOwner {
        targetSighashAllowed[TargetSighashLib.toTargetSighash(target, selector)]
        = false;

        emit RemoveTargetSighash(target, selector);
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
        _beforeValue = custody.value();

        uint256 numOperations = operations.length;
        bytes4 selector;

        for (uint256 i = 0; i < numOperations; i++) {
            if (operations[i].target == address(this)) {
                revert Aera__TargetIsHooks();
            }

            selector = bytes4(operations[i].data[0:4]);
            if (_isAllowanceSelector(selector)) {
                continue;
            }

            TargetSighash sigHash = TargetSighashLib.toTargetSighash(
                operations[i].target, selector
            );

            if (!targetSighashAllowed[sigHash]) {
                revert Aera__CallIsNotAllowed(operations[i]);
            }
        }
    }

    /// @inheritdoc IHooks
    function afterSubmit(Operation[] calldata operations)
        external
        override
        onlyCustody
    {
        uint256 day = block.timestamp / 1 days;

        if (_beforeValue > 0) {
            uint256 submitMultiplier = custody.value() * ONE / _beforeValue;

            if (currentDay == day) {
                uint256 dailyMultiplier =
                    cumulativeDailyMultiplier * submitMultiplier / ONE;
                if (dailyMultiplier < ONE - maxDailyExecutionLoss) {
                    revert Aera__ExceedsMaxDailyExecutionLoss();
                }
                cumulativeDailyMultiplier = dailyMultiplier;
            } else {
                if (submitMultiplier < ONE - maxDailyExecutionLoss) {
                    revert Aera__ExceedsMaxDailyExecutionLoss();
                }
                cumulativeDailyMultiplier = submitMultiplier;
            }
        }

        currentDay = day;
        _beforeValue = 0;

        uint256 numOperations = operations.length;
        bytes4 selector;
        address spender;
        uint256 amount;
        IERC20 asset;

        for (uint256 i = 0; i < numOperations; i++) {
            selector = bytes4(operations[i].data[0:4]);
            if (_isAllowanceSelector(selector)) {
                (spender, amount) =
                    abi.decode(operations[i].data[4:], (address, uint256));

                if (amount == 0) {
                    continue;
                }

                asset = IERC20(operations[i].target);

                if (asset.allowance(address(custody), spender) > 0) {
                    revert Aera__AllowanceIsNotZero(address(asset), spender);
                }
            }
        }
    }

    /// @inheritdoc IHooks
    function beforeFinalize() external override onlyCustody {}

    /// @inheritdoc IHooks
    function afterFinalize() external override onlyCustody {
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
        return selector == _APPROVE_SELECTOR
            || selector == _INCREASE_ALLOWANCE_SELECTOR;
    }
}
