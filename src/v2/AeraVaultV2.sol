// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./dependencies/openzeppelin/Math.sol";
import "./dependencies/openzeppelin/Ownable.sol";
import "./dependencies/openzeppelin/SafeERC20.sol";
import "./interfaces/IAssetRegistry.sol";
import "./interfaces/ICustody.sol";
import "./interfaces/IExecution.sol";

/// @title Aera Vault V2.
contract AeraVaultV2 is ICustody, Ownable {
    using SafeERC20 for IERC20;

    uint256 internal constant _ONE = 1e18;

    /// @notice Largest management fee earned proportion per one second.
    /// @dev 0.0000001% per second, i.e. 3.1536% per year.
    ///      0.0000001% * (365 * 24 * 60 * 60) = 3.1536%
    uint256 private constant _MAX_GUARDIAN_FEE = 10 ** 9;

    uint256 public immutable guardianFee;

    /// STORAGE ///

    IAssetRegistry public assetRegistry;

    IExecution public execution;

    address public guardian;

    bool public isPaused;

    /// @notice Last timestamp where guardian fee index was locked.
    uint256 public lastFeeCheckpoint = type(uint256).max;

    /// ERRORS ///

    error Aera__AssetRegistryIsZeroAddress();
    error Aera__ExecutionIsZeroAddress();
    error Aera__GuardianIsZeroAddress();
    error Aera__GuardianIsOwner();
    error Aera__GuardianFeeIsAboveMax(uint256 actual, uint256 max);
    error Aera__CallerIsNotGuardian();
    error Aera__CallerIsNotOwnerOrGuardian();
    error Aera__AssetIsNotRegistered(IERC20 poolToken);
    error Aera__CannotSweepRegisteredAsset(IERC20 asset);

    /// MODIFIERS ///

    /// @dev Throws if called by any account other than the guardian.
    modifier onlyGuardian() {
        if (msg.sender != guardian) {
            revert Aera__CallerIsNotGuardian();
        }
        _;
    }

    /// @dev Throws if called by any account other than the owner or guardian.
    modifier onlyOwnerOrGuardian() {
        if (msg.sender != owner() && msg.sender != guardian) {
            revert Aera__CallerIsNotOwnerOrGuardian();
        }
        _;
    }

    /// FUNCTIONS ///

    /// @notice Initialize the contract by deploying a new Balancer Pool using the provided factory.
    /// @dev Tokens should be unique.
    ///      The following pre-conditions are checked by Balancer in internal transactions:
    ///       If tokens are sorted in ascending order.
    ///       If swapFeePercentage is greater than the minimum and less than the maximum.
    ///       If the total sum of weights is one.
    constructor(
        address assetRegistry_,
        address execution_,
        address guardian_,
        uint256 guardianFee_
    ) {
        _checkAssetRegistryAddress(assetRegistry_);
        _checkExecutionAddress(execution_);
        _checkGuardianAddress(guardian_);

        if (guardianFee_ > _MAX_GUARDIAN_FEE) {
            revert Aera__GuardianFeeIsAboveMax(guardianFee_, _MAX_GUARDIAN_FEE);
        }

        assetRegistry = IAssetRegistry(assetRegistry_);
        execution = IExecution(execution_);
        guardian = guardian_;
        guardianFee = guardianFee_;
    }

    function deposit(AssetValue[] memory amounts) external override onlyOwner {
        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();
        uint256 numAssets = assets.length;
        uint256 numAmounts = amounts.length;

        for (uint256 i = 0; i < numAmounts; i++) {
            for (uint256 j = 0; j < numAssets; j++) {
                if (assets[j].asset < amounts[i].asset) {
                    continue;
                } else if (assets[j].asset == amounts[i].asset) {
                    break;
                } else {
                    revert Aera__AssetIsNotRegistered(amounts[i].asset);
                }
            }

            amounts[i].asset.safeTransferFrom(
                owner(),
                address(this),
                amounts[i].value
            );
        }
    }

    function withdraw(
        AssetValue[] memory amounts,
        bool force
    ) external override onlyOwner {
        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();
        uint256 feeIndex = _getFeeIndex();
        AssetValue[] memory assetAmounts = _getHoldings(assets);

        uint256 numAssets = assets.length;
        uint256 numAmounts = amounts.length;

        for (uint256 i = 0; i < numAmounts; i++) {
            for (uint256 j = 0; j < numAssets; j++) {
                if (assets[j].asset < amounts[i].asset) {
                    continue;
                } else if (assets[j].asset == amounts[i].asset) {
                    break;
                } else {
                    revert Aera__AssetIsNotRegistered(amounts[i].asset);
                }
            }

            amounts[i].asset.safeTransfer(owner(), amounts[i].value);
        }
    }

    function setGuardian(address newGuardian) external override onlyOwner {
        _checkGuardianAddress(newGuardian);

        guardian = newGuardian;
    }

    function setAssetRegistry(
        address newAssetRegistry
    ) external override onlyOwner {
        _checkAssetRegistryAddress(newAssetRegistry);

        assetRegistry = IAssetRegistry(newAssetRegistry);
    }

    function setExecution(address newExecution) external override onlyOwner {
        _checkExecutionAddress(newExecution);

        execution = IExecution(newExecution);
    }

    function finalize() external override onlyOwner {}

    function sweep(IERC20 token, uint256 amount) external override {
        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();
        uint256 numAssets = assets.length;

        for (uint256 i = 0; i < numAssets; i++) {
            if (token == assets[i].asset) {
                revert Aera__CannotSweepRegisteredAsset(token);
            }
        }

        token.safeTransfer(owner(), amount);
    }

    function pauseVault() external override onlyOwner {
        execution.claimNow();
        isPaused = true;
    }

    function resumeVault() external override onlyOwner {
        isPaused = false;
    }

    function endRebalance() external override onlyOwnerOrGuardian {
        execution.endRebalance();
    }

    function endRebalanceEarly() external override onlyOwnerOrGuardian {
        execution.claimNow();
    }

    function startRebalance(
        AssetValue[] memory assetWeights,
        uint256 startTime,
        uint256 endTime
    ) external override {}

    function claimGuardianFees() external override {}

    function holdings()
        public
        view
        override
        returns (AssetValue[] memory assetAmounts)
    {
        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();

        return _getHoldings(assets);
    }

    /// INTERNAL FUNCTIONS ///

    /// @notice Calculate guardian fee index.
    /// @dev Will only be called by lockGuardianFees().
    function _getFeeIndex() internal view returns (uint256) {
        uint256 feeIndex = 0;

        if (block.timestamp > lastFeeCheckpoint) {
            feeIndex = block.timestamp - lastFeeCheckpoint;
        }

        return feeIndex;
    }

    function _getHoldings(
        IAssetRegistry.AssetInformation[] memory assets
    ) internal view returns (AssetValue[] memory assetAmounts) {
        IExecution.AssetValue[] memory executionHoldings = execution.holdings();

        uint256 numAssets = assets.length;
        uint256 numExecutionHoldings = executionHoldings.length;

        assetAmounts = new AssetValue[](numAssets);

        for (uint256 i = 0; i < numAssets; i++) {
            assetAmounts[i] = AssetValue({
                asset: assets[i].asset,
                value: assets[i].asset.balanceOf(address(this))
            });
        }
        for (uint256 i = 0; i < numExecutionHoldings; i++) {
            for (uint256 j = 0; j < numAssets; j++) {
                if (assets[j].asset < executionHoldings[i].asset) {
                    continue;
                } else {
                    if (assets[j].asset == executionHoldings[i].asset) {
                        if (executionHoldings[i].value > 0) {
                            assetAmounts[j].value += executionHoldings[i].value;
                        }
                    }
                    break;
                }
            }
        }
    }

    /// @notice Reset allowance of token for a spender.
    /// @dev Will only be called by setAllowance() and depositUnderlyingAsset().
    /// @param token Token of address to set allowance.
    /// @param spender Address to give spend approval to.
    function _clearAllowance(IERC20 token, address spender) internal {
        uint256 allowance = token.allowance(address(this), spender);
        if (allowance > 0) {
            token.safeDecreaseAllowance(spender, allowance);
        }
    }

    /// @notice Set allowance of token for a spender.
    /// @dev Will only be called by initialDeposit(), depositTokens(),
    ///      depositToYieldTokens() and depositUnderlyingAsset().
    /// @param token Token of address to set allowance.
    /// @param spender Address to give spend approval to.
    /// @param amount Amount to approve for spending.
    function _setAllowance(
        IERC20 token,
        address spender,
        uint256 amount
    ) internal {
        _clearAllowance(token, spender);
        token.safeIncreaseAllowance(spender, amount);
    }

    /// @notice Check if the address can be a guardian.
    /// @dev Will only be called by constructor and setGuardian()
    /// @param newGuardian Address to check.
    function _checkGuardianAddress(address newGuardian) internal view {
        if (newGuardian == address(0)) {
            revert Aera__GuardianIsZeroAddress();
        }
        if (newGuardian == owner()) {
            revert Aera__GuardianIsOwner();
        }
    }

    /// @notice Check if the address can be an asset registry.
    /// @dev Will only be called by constructor and setAssetRegistry()
    /// @param newAssetRegistry Address to check.
    function _checkAssetRegistryAddress(
        address newAssetRegistry
    ) internal pure {
        if (newAssetRegistry == address(0)) {
            revert Aera__AssetRegistryIsZeroAddress();
        }
    }

    /// @notice Check if the address can be an execution.
    /// @dev Will only be called by constructor and setExecution()
    /// @param newExecution Address to check.
    function _checkExecutionAddress(address newExecution) internal pure {
        if (newExecution == address(0)) {
            revert Aera__ExecutionIsZeroAddress();
        }
    }
}
