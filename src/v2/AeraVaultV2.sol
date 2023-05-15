// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./AeraCustody.sol";
import "./dependencies/openzeppelin/IERC4626.sol";
import "./interfaces/IBalancerExecution.sol";

/// @title Aera Vault V2 Custody contract.
contract AeraVaultV2 is AeraCustody {
    using SafeERC20 for IERC20;

    /// @notice Minimum action threshold for erc20 assets measured in base token terms.
    uint256 public immutable minThreshold;

    /// @notice Minimum action threshold for yield bearing assets measured in base token terms.
    uint256 public immutable minYieldActionThreshold;

    /// ERRORS ///

    error Aera__MinThresholdIsZero();
    error Aera__MinYieldActionThresholdIsZero();

    /// FUNCTIONS ///

    /// @notice Initialize the custody contract by providing references to
    ///         asset registry, execution contracts and other parameters.
    /// @param assetRegistry_ The address of asset registry.
    /// @param execution_ The address of execution module.
    /// @param guardian_ The address of guardian.
    /// @param guardianFee_ Guardian fee per second in 18 decimal fixed point format.
    /// @param minThreshold_ Minimum action threshold for erc20 assets measured
    ///                      in base token terms.
    /// @param minYieldActionThreshold_ Minimum action threshold for yield bearing assets
    ///                                 measured in base token terms.
    constructor(
        address assetRegistry_,
        address execution_,
        address guardian_,
        uint256 guardianFee_,
        uint256 minThreshold_,
        uint256 minYieldActionThreshold_
    ) AeraCustody(assetRegistry_, execution_, guardian_, guardianFee_) {
        if (minThreshold_ == 0) {
            revert Aera__MinThresholdIsZero();
        }
        if (minYieldActionThreshold_ == 0) {
            revert Aera__MinYieldActionThresholdIsZero();
        }

        minThreshold = minThreshold_;
        minYieldActionThreshold = minYieldActionThreshold_;
    }

    /// @inheritdoc ICustody
    function deposit(
        AssetValue[] calldata amounts
    ) external override nonReentrant onlyOwner whenNotFinalized {
        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();
        uint256 numAmounts = amounts.length;
        AssetValue memory assetValue;
        bool isRegistered;

        for (uint256 i = 0; i < numAmounts; i++) {
            assetValue = amounts[i];
            (isRegistered, ) = _isAssetRegistered(assetValue.asset, assets);

            if (!isRegistered) {
                revert Aera__AssetIsNotRegistered(assetValue.asset);
            }

            for (uint256 j = 0; j < numAmounts; j++) {
                if (i != j && assetValue.asset == amounts[j].asset) {
                    revert Aera__AssetIsDuplicated(assetValue.asset);
                }
            }

            assetValue.asset.safeTransferFrom(
                owner(),
                address(this),
                assetValue.value
            );
        }

        emit Deposit(amounts);
    }

    /// @inheritdoc ICustody
    function withdraw(
        AssetValue[] calldata amounts,
        bool force
    ) external override nonReentrant onlyOwner whenNotFinalized {
        _updateGuardianFees();

        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();

        uint256 numAssets = assets.length;
        uint256 numAmounts = amounts.length;
        uint256[] memory assetIndexes = _checkWithdrawRequest(assets, amounts);
        AssetValue memory assetValue;

        for (uint256 i = 0; i < numAmounts; i++) {
            assetValue = amounts[i];

            if (assetValue.asset.balanceOf(address(this)) < assetValue.value) {
                if (!force) {
                    revert Aera__AmountExceedsAvailable(
                        assetValue.asset,
                        assetValue.value,
                        assetValue.asset.balanceOf(address(this))
                    );
                }

                execution.claimNow();
                break;
            }
        }

        uint256[] memory underlyingIndexes = _getUnderlyingIndexes(assets);
        uint256[] memory withdrawAmounts = new uint256[](numAssets);
        (
            uint256[] memory spotPrices,
            uint256[] memory assetUnits
        ) = _getSpotPricesAndUnits(assets);

        uint256 assetIndex;
        for (uint256 i = 0; i < numAmounts; i++) {
            assetValue = amounts[i];

            if (assetValue.value == 0) {
                continue;
            }

            assetIndex = assetIndexes[i];

            if (assets[assetIndex].isERC4626) {
                if (assets[assetIndex].withdrawable) {
                    assetValue.asset.safeTransfer(owner(), assetValue.value);
                } else {
                    withdrawAmounts[
                        underlyingIndexes[assetIndex]
                    ] += _withdrawUnderlyingAsset(
                        assets[assetIndex],
                        assetValue.value,
                        spotPrices[assetIndex],
                        assetUnits[assetIndex]
                    );
                }
            } else {
                withdrawAmounts[assetIndex] += assetValue.value;
            }
        }

        for (uint256 i = 0; i < numAssets; i++) {
            if (withdrawAmounts[i] > 0) {
                assets[i].asset.safeTransfer(owner(), withdrawAmounts[i]);
            }
        }

        emit Withdraw(amounts, force);
    }

    /// @inheritdoc ICustody
    function startRebalance(
        AssetValue[] calldata assetWeights,
        uint256 startTime,
        uint256 endTime
    )
        external
        override
        nonReentrant
        onlyGuardian
        whenNotPaused
        whenNotFinalized
    {
        _updateGuardianFees();

        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();
        uint256 numAssets = assets.length;

        uint256[] memory targetWeights = _getTargetWeights(
            assets,
            assetWeights
        );
        uint256[] memory underlyingTargetWeights = _adjustYieldAssets(
            assets,
            targetWeights
        );
        underlyingTargetWeights = _normalizeWeights(underlyingTargetWeights);

        uint256 numValidAssets;

        for (uint256 i = 0; i < numAssets; i++) {
            if (!assets[i].isERC4626 && underlyingTargetWeights[i] > 0) {
                numValidAssets++;
            }
        }

        if (numValidAssets > 0) {
            IExecution.AssetRebalanceRequest[]
                memory requests = new IExecution.AssetRebalanceRequest[](
                    numValidAssets
                );

            AssetValue[] memory assetAmounts = _getHoldings(assets);

            IAssetRegistry.AssetInformation memory asset;
            uint256 index;
            for (uint256 i = 0; i < numAssets; i++) {
                asset = assets[i];
                if (!asset.isERC4626 && underlyingTargetWeights[i] > 0) {
                    requests[index] = IExecution.AssetRebalanceRequest(
                        asset.asset,
                        assetAmounts[i].value,
                        underlyingTargetWeights[i]
                    );
                    _setAllowance(
                        asset.asset,
                        address(execution),
                        assetAmounts[i].value
                    );
                    index++;
                }
            }

            execution.startRebalance(requests, startTime, endTime);
        }

        rebalanceEndTime = endTime;

        emit StartRebalance(assetWeights, startTime, endTime);
    }

    /// INTERNAL FUNCTIONS ///

    /// @notice Check request to withdraw.
    /// @param assets Struct details for asset information from asset registry.
    /// @param amounts Struct details for assets and amounts to withdraw.
    /// @return assetIndexes Array of requested asset indexes in order of registered assets.
    function _checkWithdrawRequest(
        IAssetRegistry.AssetInformation[] memory assets,
        AssetValue[] memory amounts
    ) internal view returns (uint256[] memory assetIndexes) {
        uint256 numAmounts = amounts.length;

        AssetValue[] memory assetAmounts = _getHoldings(assets);
        assetIndexes = new uint256[](numAmounts);

        bool isRegistered;
        IERC4626 yieldAsset;
        AssetValue memory assetValue;
        uint256 availableAmount;
        uint256 index;

        for (uint256 i = 0; i < numAmounts; i++) {
            assetValue = amounts[i];
            (isRegistered, index) = _isAssetRegistered(
                assetValue.asset,
                assets
            );

            if (!isRegistered) {
                revert Aera__AssetIsNotRegistered(assetValue.asset);
            }

            for (uint256 j = 0; j < numAmounts; j++) {
                if (i != j && assetValue.asset == amounts[j].asset) {
                    revert Aera__AssetIsDuplicated(assetValue.asset);
                }
            }

            availableAmount = assetAmounts[index].value;

            if (assets[index].isERC4626 && !assets[index].withdrawable) {
                yieldAsset = IERC4626(address(assets[index].asset));
                availableAmount = yieldAsset.convertToAssets(availableAmount);
                availableAmount = Math.min(
                    availableAmount,
                    yieldAsset.maxWithdraw(address(this))
                );
            }

            if (availableAmount < assetValue.value) {
                revert Aera__AmountExceedsAvailable(
                    assetValue.asset,
                    assetValue.value,
                    availableAmount
                );
            }

            assetIndexes[i] = index;
        }
    }

    /// @notice Adjust the balance of underlying assets in yield assets.
    /// @param assets Struct details for registered assets in asset registry.
    /// @param targetWeights Target weights of assets.
    /// @return underlyingTargetWeights Total target weights of underlying assets.
    function _adjustYieldAssets(
        IAssetRegistry.AssetInformation[] memory assets,
        uint256[] memory targetWeights
    ) internal returns (uint256[] memory underlyingTargetWeights) {
        uint256 numAssets = assets.length;

        uint256[] memory underlyingIndexes = _getUnderlyingIndexes(assets);
        (
            uint256[] memory spotPrices,
            uint256[] memory assetUnits
        ) = _getSpotPricesAndUnits(assets);

        uint256[] memory depositAmounts = new uint256[](numAssets);
        uint256[] memory withdrawAmounts = new uint256[](numAssets);
        uint256[] memory currentWeights = new uint256[](numAssets);
        uint256 totalValue;

        (
            depositAmounts,
            withdrawAmounts,
            currentWeights,
            totalValue
        ) = _calcAdjustmentAmounts(
            assets,
            targetWeights,
            spotPrices,
            assetUnits
        );

        underlyingTargetWeights = new uint256[](numAssets);
        for (uint256 i = 0; i < numAssets; i++) {
            if (assets[i].isERC4626) {
                underlyingTargetWeights[underlyingIndexes[i]] += targetWeights[
                    i
                ];
            } else {
                underlyingTargetWeights[i] += targetWeights[i];
            }
        }

        for (uint256 i = 0; i < numAssets; i++) {
            if (!assets[i].isERC4626 || withdrawAmounts[i] == 0) {
                continue;
            }

            if (
                _withdrawUnderlyingAsset(
                    assets[i],
                    withdrawAmounts[i],
                    spotPrices[i],
                    assetUnits[i]
                ) > 0
            ) {
                underlyingTargetWeights[underlyingIndexes[i]] -= targetWeights[
                    i
                ];
            } else {
                underlyingTargetWeights[underlyingIndexes[i]] -= currentWeights[
                    i
                ];
            }
        }

        AssetValue[] memory assetAmounts = _getHoldings(assets);
        for (uint256 i = 0; i < numAssets; i++) {
            if (!assets[i].isERC4626 || depositAmounts[i] == 0) {
                continue;
            }

            if (
                assetAmounts[underlyingIndexes[i]].value > depositAmounts[i] &&
                _depositUnderlyingAsset(
                    assets[i],
                    depositAmounts[i],
                    spotPrices[i],
                    assetUnits[i]
                ) >
                0
            ) {
                assetAmounts[underlyingIndexes[i]].value -= depositAmounts[i];
                underlyingTargetWeights[underlyingIndexes[i]] -= targetWeights[
                    i
                ];
            } else {
                underlyingTargetWeights[underlyingIndexes[i]] -= currentWeights[
                    i
                ];
            }
        }

        uint256 deviation;

        for (uint256 i = 0; i < numAssets; i++) {
            if (assets[i].isERC4626) {
                continue;
            }

            if (underlyingTargetWeights[i] > currentWeights[i]) {
                deviation = underlyingTargetWeights[i] - currentWeights[i];
            } else {
                deviation = currentWeights[i] - underlyingTargetWeights[i];
            }

            if ((totalValue * deviation) / _ONE < minThreshold) {
                underlyingTargetWeights[i] = 0;
            }
        }
    }

    /// @notice Calculate the amounts of underlying assets of yield assets to adjust.
    /// @param assets Struct details for registered assets in asset registry.
    /// @param targetWeights Reordered target weights.
    /// @param spotPrices Spot prices of assets.
    /// @param assetUnits Units of assets.
    /// @return depositAmounts Amounts of underlying assets to deposit to yield tokens.
    /// @return withdrawAmounts Amounts of underlying assets to withdraw from yield tokens.
    /// @return currentWeights Current weights of assets.
    /// @return totalValue Total value of assets measured in base token terms.
    function _calcAdjustmentAmounts(
        IAssetRegistry.AssetInformation[] memory assets,
        uint256[] memory targetWeights,
        uint256[] memory spotPrices,
        uint256[] memory assetUnits
    )
        internal
        view
        returns (
            uint256[] memory depositAmounts,
            uint256[] memory withdrawAmounts,
            uint256[] memory currentWeights,
            uint256 totalValue
        )
    {
        uint256 numAssets = assets.length;
        depositAmounts = new uint256[](numAssets);
        withdrawAmounts = new uint256[](numAssets);
        currentWeights = new uint256[](numAssets);
        uint256[] memory underlyingBalances = new uint256[](numAssets);
        uint256[] memory values = new uint256[](numAssets);
        AssetValue[] memory assetAmounts = _getHoldings(assets);

        {
            uint256 balance;
            for (uint256 i = 0; i < numAssets; i++) {
                if (assets[i].isERC4626) {
                    balance = IERC4626(address(assets[i].asset))
                        .convertToAssets(assetAmounts[i].value);
                    underlyingBalances[i] = balance;
                } else {
                    balance = assetAmounts[i].value;
                }

                values[i] = (balance * spotPrices[i]) / assetUnits[i];
                totalValue += values[i];
            }
        }

        uint256 targetBalance;
        for (uint256 i = 0; i < numAssets; i++) {
            currentWeights[i] = (values[i] * _ONE) / totalValue;

            if (!assets[i].isERC4626) {
                continue;
            }

            targetBalance =
                (totalValue * targetWeights[i] * assetUnits[i]) /
                spotPrices[i] /
                _ONE;
            if (targetBalance > underlyingBalances[i]) {
                depositAmounts[i] = targetBalance - underlyingBalances[i];
            } else {
                withdrawAmounts[i] = underlyingBalances[i] - targetBalance;
            }
        }
    }

    /// @notice Deposit the amount of underlying asset to yield asset.
    /// @param asset Struct detail for yield asset.
    /// @param amount Amount of underlying asset to withdraw from yield asset.
    /// @param spotPrice Oracle price.
    /// @param assetUnit Unit of underlying asset.
    /// @return Exact deposited amount of underlying asset.
    function _depositUnderlyingAsset(
        IAssetRegistry.AssetInformation memory asset,
        uint256 amount,
        uint256 spotPrice,
        uint256 assetUnit
    ) internal returns (uint256) {
        uint256 value = (amount * spotPrice) / assetUnit;
        if (value < minYieldActionThreshold) {
            return 0;
        }

        IERC4626 yieldAsset = IERC4626(address(asset.asset));
        IERC20 underlyingAsset = IERC20(yieldAsset.asset());

        try yieldAsset.maxDeposit(address(this)) returns (
            uint256 maxDepositAmount
        ) {
            if (maxDepositAmount == 0) {
                return 0;
            }

            uint256 depositAmount = Math.min(amount, maxDepositAmount);

            _setAllowance(underlyingAsset, address(yieldAsset), depositAmount);

            yieldAsset.deposit(depositAmount, address(this));

            _clearAllowance(underlyingAsset, address(yieldAsset));

            return depositAmount;
        } catch {}

        return 0;
    }

    /// @notice Withdraw the amount of underlying asset from yield asset.
    /// @param asset Struct detail for yield asset.
    /// @param amount Amount of underlying asset to withdraw from yield asset.
    /// @param spotPrice Oracle price.
    /// @param assetUnit Unit of underlying asset.
    /// @return Exact withdrawn amount of underlying asset.
    function _withdrawUnderlyingAsset(
        IAssetRegistry.AssetInformation memory asset,
        uint256 amount,
        uint256 spotPrice,
        uint256 assetUnit
    ) internal returns (uint256) {
        uint256 value = (amount * spotPrice) / assetUnit;
        if (value < minYieldActionThreshold) {
            return 0;
        }

        IERC4626 yieldAsset = IERC4626(address(asset.asset));
        IERC20 underlyingAsset = IERC20(yieldAsset.asset());

        try yieldAsset.maxWithdraw(address(this)) returns (
            uint256 maxWithdrawalAmount
        ) {
            if (maxWithdrawalAmount == 0) {
                return 0;
            }

            uint256 balance = underlyingAsset.balanceOf(address(this));

            yieldAsset.withdraw(
                Math.min(amount, maxWithdrawalAmount),
                address(this),
                address(this)
            );

            return underlyingAsset.balanceOf(address(this)) - balance;
        } catch {}

        return 0;
    }

    /// @notice Get target weights in registered asset order.
    /// @param assets Struct details for registered assets in asset registry.
    /// @param assetWeights Struct details for weights of assets.
    /// @return targetWeights Reordered target weights.
    function _getTargetWeights(
        IAssetRegistry.AssetInformation[] memory assets,
        AssetValue[] calldata assetWeights
    ) internal pure returns (uint256[] memory targetWeights) {
        uint256 numAssets = assets.length;
        uint256 numAssetWeights = assetWeights.length;

        if (numAssets != numAssetWeights) {
            revert Aera__ValueLengthIsNotSame(numAssets, numAssetWeights);
        }

        targetWeights = new uint256[](numAssetWeights);

        AssetValue memory assetWeight;
        bool isRegistered;
        uint256 index;
        uint256 weightSum = 0;

        for (uint256 i = 0; i < numAssetWeights; i++) {
            assetWeight = assetWeights[i];

            (isRegistered, index) = _isAssetRegistered(
                assetWeight.asset,
                assets
            );

            if (!isRegistered) {
                revert Aera__AssetIsNotRegistered(assetWeight.asset);
            }

            targetWeights[index] = assetWeight.value;
            weightSum += assetWeight.value;

            for (uint256 j = 0; j < numAssetWeights; j++) {
                if (i != j && assetWeight.asset == assetWeights[j].asset) {
                    revert Aera__AssetIsDuplicated(assetWeight.asset);
                }
            }
        }

        if (weightSum != _ONE) {
            revert Aera__SumOfWeightsIsNotOne();
        }
    }

    /// @notice Normalize weights to make a sum of weights one.
    /// @param weights Array of weights to be normalized.
    /// @return newWeights Array of normalized weights.
    function _normalizeWeights(
        uint256[] memory weights
    ) internal pure returns (uint256[] memory newWeights) {
        uint256 numWeights = weights.length;
        newWeights = new uint256[](numWeights);

        uint256 weightSum;
        for (uint256 i = 0; i < numWeights; i++) {
            weightSum += weights[i];
        }

        if (weightSum == _ONE) {
            return weights;
        }

        uint256 adjustedSum;
        for (uint256 i = 0; i < numWeights; i++) {
            if (weights[i] > 0) {
                newWeights[i] = (weights[i] * _ONE) / weightSum;
                adjustedSum += newWeights[i];
            }
        }

        if (adjustedSum < _ONE) {
            for (uint256 i = 0; i < numWeights; i++) {
                if (newWeights[i] > 0) {
                    newWeights[i] = newWeights[i] + _ONE - adjustedSum;
                    break;
                }
            }
        } else if (adjustedSum > _ONE) {
            uint256 deviation = adjustedSum - _ONE;
            for (uint256 i = 0; i < numWeights; i++) {
                if (newWeights[i] > deviation) {
                    newWeights[i] -= deviation;
                    break;
                }
            }
        }
    }

    /// @notice Get spot prices and units of requested assets.
    /// @param assets Struct details for registered assets in asset registry.
    /// @return spotPrices Spot prices of assets.
    /// @return assetUnits Units of assets.
    function _getSpotPricesAndUnits(
        IAssetRegistry.AssetInformation[] memory assets
    )
        internal
        view
        returns (uint256[] memory spotPrices, uint256[] memory assetUnits)
    {
        uint256 numAssets = assets.length;

        IAssetRegistry.AssetPriceReading[]
            memory erc20SpotPrices = assetRegistry.spotPrices();
        uint256 numERC20SpotPrices = erc20SpotPrices.length;

        spotPrices = new uint256[](numAssets);
        assetUnits = new uint256[](numAssets);

        IAssetRegistry.AssetInformation memory asset;
        address underlyingAsset;

        for (uint256 i = 0; i < numAssets; i++) {
            asset = assets[i];

            if (asset.isERC4626) {
                underlyingAsset = IERC4626(address(asset.asset)).asset();
                for (uint256 j = 0; j < numERC20SpotPrices; j++) {
                    if (underlyingAsset == address(erc20SpotPrices[j].asset)) {
                        spotPrices[i] = erc20SpotPrices[j].spotPrice;
                        assetUnits[i] =
                            10 ** IERC20Metadata(underlyingAsset).decimals();
                        break;
                    }
                }
            } else {
                for (uint256 j = 0; j < numERC20SpotPrices; j++) {
                    if (asset.asset == erc20SpotPrices[j].asset) {
                        spotPrices[i] = erc20SpotPrices[j].spotPrice;
                        break;
                    }
                }

                assetUnits[i] =
                    10 ** IERC20Metadata(address(asset.asset)).decimals();
            }
        }
    }

    /// @notice Returns an array of underlying asset indexes.
    /// @param assets Struct details for registered assets in asset registry.
    /// @return underlyingIndexes Array of underlying asset indexes.
    function _getUnderlyingIndexes(
        IAssetRegistry.AssetInformation[] memory assets
    ) internal view returns (uint256[] memory underlyingIndexes) {
        uint256 numAssets = assets.length;
        underlyingIndexes = new uint256[](numAssets);

        for (uint256 i = 0; i < numAssets; i++) {
            if (!assets[i].isERC4626) {
                continue;
            }

            for (uint256 j = 0; j < numAssets; j++) {
                if (
                    IERC4626(address(assets[i].asset)).asset() ==
                    address(assets[j].asset)
                ) {
                    underlyingIndexes[i] = j;
                    break;
                }
            }
        }
    }

    /// @notice Check if the address can be an execution.
    /// @param newExecution Address to check.
    function _checkExecutionAddress(
        address newExecution
    ) internal view override {
        if (newExecution == address(0)) {
            revert Aera__ExecutionIsZeroAddress();
        }
        if (
            !ERC165Checker.supportsInterface(
                newExecution,
                type(IBalancerExecution).interfaceId
            )
        ) {
            revert Aera__ExecutionIsNotValid(newExecution);
        }
    }
}
