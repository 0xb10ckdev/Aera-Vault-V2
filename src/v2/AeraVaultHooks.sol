// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/ERC165.sol";
import "@openzeppelin/ERC165Checker.sol";
import "@openzeppelin/IERC4626.sol";
import "@openzeppelin/Math.sol";
import "@openzeppelin/Ownable.sol";
import "@openzeppelin/Pausable.sol";
import "@openzeppelin/ReentrancyGuard.sol";
import "@openzeppelin/SafeERC20.sol";
import "./interfaces/IHooks.sol";
import "./interfaces/ICustody.sol";
import {ONE} from "./Constants.sol";

/// @title Aera Vault Hooks contract.
contract AeraVaultHooks is IHooks, ERC165, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    bytes4 internal constant _APPROVE_SELECTOR =
        bytes4(keccak256("approve(address, uint256)"));

    bytes4 internal constant _INCREASE_ALLOWANCE_SELECTOR =
        bytes4(keccak256("increaseAllowance(address, uint256)"));

    ICustody public immutable custody;

    /// STORAGE ///

    uint256 public maxDailyExecutionLoss;

    uint256 public currentDay;

    uint256 public cumulativeDailyMultiplier;

    mapping(TargetSighash => bool) public targetSighashAllowlist;

    uint256 public beforeValue;

    /// MODIFIERS ///

    /// @dev Throws if called by any account other than the custody.
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
    /// @param targetSighashAllowlistValues Array of target sighash to allow.
    constructor(
        address custody_,
        uint256 maxDailyExecutionLoss_,
        TargetSighash[] memory targetSighashAllowlistValues
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

        uint256 numTargetSighashValues = targetSighashAllowlistValues.length;

        for (uint256 i = 0; i < numTargetSighashValues; i++) {
            targetSighashAllowlist[targetSighashAllowlistValues[i]] = true;
        }

        custody = ICustody(custody_);
        maxDailyExecutionLoss = maxDailyExecutionLoss_;
        currentDay = block.timestamp / 1 days;
        cumulativeDailyMultiplier = ONE;
    }

    function addTargetSighash(TargetSighash targetSighash)
        external
        override
        onlyOwner
    {
        targetSighashAllowlist[targetSighash] = true;

        emit AddTargetSighash(targetSighash);
    }

    function removeTargetSighash(TargetSighash targetSighash)
        external
        override
        onlyOwner
    {
        targetSighashAllowlist[targetSighash] = false;

        emit RemoveTargetSighash(targetSighash);
    }

    function beforeDeposit(AssetValue[] memory amounts)
        external
        override
        onlyCustody
    {}

    function afterDeposit(AssetValue[] memory amounts)
        external
        override
        onlyCustody
    {}

    function beforeWithdraw(AssetValue[] memory amounts)
        external
        override
        onlyCustody
    {}

    function afterWithdraw(AssetValue[] memory amounts)
        external
        override
        onlyCustody
    {}

    function beforeSubmit(Operation[] calldata operations)
        external
        override
        onlyCustody
    {
        beforeValue = custody.value();

        uint256 numOperations = operations.length;
        bytes4 selector;

        for (uint256 i = 0; i < numOperations; i++) {
            if (operations[i].target == address(this)) {
                revert Aera__TargetIsHooks();
            }

            selector = bytes4(operations[i].data[0:4]);
            if (
                selector == _APPROVE_SELECTOR
                    || selector == _INCREASE_ALLOWANCE_SELECTOR
            ) {
                continue;
            }

            TargetSighash sigHash = TargetSighash.wrap(
                uint160(operations[i].target) << 32 | uint32(selector)
            );

            if (!targetSighashAllowlist[sigHash]) {
                revert Aera__CallIsNotAllowed(operations[i]);
            }
        }
    }

    function afterSubmit(Operation[] calldata operations)
        external
        override
        onlyCustody
    {
        uint256 dailyMultiplier = cumulativeDailyMultiplier;

        if (beforeValue > 0) {
            uint256 value = custody.value();
            uint256 submitMultiplier = value * ONE / beforeValue;

            if (currentDay == block.timestamp / 1 days) {
                dailyMultiplier *= submitMultiplier;
                if (dailyMultiplier < ONE - maxDailyExecutionLoss) {
                    revert Aera__ExceedsMaxDailyExecutionLoss();
                }
            } else {
                if (submitMultiplier < ONE - maxDailyExecutionLoss) {
                    revert Aera__ExceedsMaxDailyExecutionLoss();
                }
                dailyMultiplier = submitMultiplier;
            }
        }

        IAssetRegistry.AssetInformation[] memory assets =
            custody.assetRegistry().assets();

        uint256 numOperations = operations.length;
        bytes4 selector;
        address spender;
        IERC20 asset;

        for (uint256 i = 0; i < numOperations; i++) {
            selector = bytes4(operations[i].data[0:4]);
            if (
                selector == _APPROVE_SELECTOR
                    || selector == _INCREASE_ALLOWANCE_SELECTOR
            ) {
                (spender,) =
                    abi.decode(operations[i].data[4:], (address, uint256));
                asset = IERC20(operations[i].target);

                if (_isAssetRegistered(asset, assets)) {
                    _clearAllowance(asset, spender);
                }
            }
        }

        cumulativeDailyMultiplier = dailyMultiplier;
    }

    function beforeFinalize() external override onlyCustody {}

    function afterFinalize() external override onlyCustody {
        maxDailyExecutionLoss = 0;
    }

    /// INTERNAL FUNCTIONS ///

    /// @notice Check whether asset is registered to asset registry or not.
    /// @param asset Asset to check.
    /// @param registeredAssets Array of registered assets.
    /// @return isRegistered True if asset is registered.
    function _isAssetRegistered(
        IERC20 asset,
        IAssetRegistry.AssetInformation[] memory registeredAssets
    ) internal pure returns (bool isRegistered) {
        uint256 numAssets = registeredAssets.length;

        for (uint256 i = 0; i < numAssets; i++) {
            if (registeredAssets[i].asset < asset) {
                continue;
            }
            if (registeredAssets[i].asset == asset) {
                return !registeredAssets[i].isERC4626;
            }
            break;
        }
    }

    /// @notice Reset allowance of token for a spender.
    /// @param token Token of address to set allowance.
    /// @param spender Address to give spend approval to.
    function _clearAllowance(IERC20 token, address spender) internal {
        uint256 allowance = token.allowance(address(this), spender);
        if (allowance > 0) {
            token.safeDecreaseAllowance(spender, allowance);
        }
    }
}