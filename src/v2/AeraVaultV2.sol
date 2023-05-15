// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./dependencies/openzeppelin/ERC165Checker.sol";
import "./dependencies/openzeppelin/IERC4626.sol";
import "./dependencies/openzeppelin/Math.sol";
import "./dependencies/openzeppelin/Ownable.sol";
import "./dependencies/openzeppelin/Pausable.sol";
import "./dependencies/openzeppelin/ReentrancyGuard.sol";
import "./dependencies/openzeppelin/SafeERC20.sol";
import "./interfaces/IAssetRegistry.sol";
import "./interfaces/IBalancerExecution.sol";
import "./interfaces/ICustody.sol";
import "./interfaces/IExecution.sol";

/// @title Aera Vault V2 Custody contract.
contract AeraVaultV2 is ICustody, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 internal constant _ONE = 1e18;

    /// @notice Largest possible guardian fee earned proportion per one second.
    /// @dev 0.0000001% per second, i.e. 3.1536% per year.
    ///      0.0000001% * (365 * 24 * 60 * 60) = 3.1536%
    uint256 private constant _MAX_GUARDIAN_FEE = 10 ** 9;

    /// @notice Guardian fee per second in 18 decimal fixed point format.
    uint256 public immutable guardianFee;

    /// @notice Minimum action threshold for erc20 assets measured in base token terms.
    uint256 public immutable minThreshold;

    /// @notice Minimum action threshold for yield bearing assets measured in base token terms.
    uint256 public immutable minYieldActionThreshold;

    /// STORAGE ///

    /// @notice The address of asset registry.
    IAssetRegistry public assetRegistry;

    /// @notice The address of execution module.
    IExecution public execution;

    /// @notice The address of guardian.
    address public guardian;

    /// @notice Indicates that the Vault has been finalized.
    bool public finalized;

    /// @notice Timestamp at when rebalancing ends.
    uint256 public rebalanceEndTime;

    /// @notice Fee earned amount for each guardian.
    mapping(address => AssetValue[]) public guardiansFee;

    /// @notice Total guardian fee earned amount.
    mapping(IERC20 => uint256) public guardiansFeeTotal;

    /// @notice Last timestamp where guardian fee index was locked.
    uint256 public lastFeeCheckpoint = type(uint256).max;

    /// ERRORS ///

    error Aera__MinThresholdIsZero();
    error Aera__MinYieldActionThresholdIsZero();

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

    /// @dev Throws if called after the vault is finalized.
    modifier whenNotFinalized() {
        if (finalized) {
            revert Aera__VaultIsFinalized();
        }
        _;
    }

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
    ) {
        _checkAssetRegistryAddress(assetRegistry_);
        _checkExecutionAddress(execution_);
        _checkGuardianAddress(guardian_);

        if (guardianFee_ > _MAX_GUARDIAN_FEE) {
            revert Aera__GuardianFeeIsAboveMax(guardianFee_, _MAX_GUARDIAN_FEE);
        }
        if (minThreshold_ == 0) {
            revert Aera__MinThresholdIsZero();
        }
        if (minYieldActionThreshold_ == 0) {
            revert Aera__MinYieldActionThresholdIsZero();
        }

        assetRegistry = IAssetRegistry(assetRegistry_);
        execution = IExecution(execution_);
        guardian = guardian_;
        guardianFee = guardianFee_;
        minThreshold = minThreshold_;
        minYieldActionThreshold = minYieldActionThreshold_;
        lastFeeCheckpoint = block.timestamp;

        emit SetAssetRegistry(assetRegistry_);
        emit SetExecution(execution_);
        emit SetGuardian(guardian_);
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
            if (assetValue.value > 0) {
                assetIndex = assetIndexes[i];

                if (assets[assetIndex].isERC4626) {
                    if (assets[assetIndex].withdrawable) {
                        assetValue.asset.safeTransfer(
                            owner(),
                            assetValue.value
                        );
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
        }

        for (uint256 i = 0; i < numAssets; i++) {
            if (withdrawAmounts[i] > 0) {
                assets[i].asset.safeTransfer(owner(), withdrawAmounts[i]);
            }
        }

        emit Withdraw(amounts, force);
    }

    /// @inheritdoc ICustody
    function setGuardian(
        address newGuardian
    ) external override onlyOwner whenNotFinalized {
        _checkGuardianAddress(newGuardian);
        _updateGuardianFees();

        guardian = newGuardian;

        emit SetGuardian(newGuardian);
    }

    /// @inheritdoc ICustody
    function setAssetRegistry(
        address newAssetRegistry
    ) external override onlyOwner whenNotFinalized {
        _checkAssetRegistryAddress(newAssetRegistry);
        _updateGuardianFees();

        assetRegistry = IAssetRegistry(newAssetRegistry);

        emit SetAssetRegistry(newAssetRegistry);
    }

    /// @inheritdoc ICustody
    function setExecution(
        address newExecution
    ) external override onlyOwner whenNotFinalized {
        _checkExecutionAddress(newExecution);

        // Note: we could remove this but leaving it to protect the guardian
        _updateGuardianFees();

        execution = IExecution(newExecution);

        emit SetExecution(newExecution);
    }

    /// @inheritdoc ICustody
    function finalize()
        external
        override
        nonReentrant
        onlyOwner
        whenNotFinalized
    {
        finalized = true;

        _updateGuardianFees();

        execution.claimNow();

        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();
        AssetValue[] memory assetAmounts = _getHoldings(assets);
        uint256 numAssetAmounts = assetAmounts.length;

        for (uint256 i = 0; i < numAssetAmounts; i++) {
            assetAmounts[i].asset.safeTransfer(owner(), assetAmounts[i].value);
        }

        emit Finalized();
    }

    /// @inheritdoc ICustody
    function sweep(
        IERC20 token,
        uint256 amount
    ) external override nonReentrant {
        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();

        (bool isRegistered, ) = _isAssetRegistered(token, assets);

        if (isRegistered) {
            revert Aera__CannotSweepRegisteredAsset();
        }

        token.safeTransfer(owner(), amount);

        emit Sweep(token, amount);
    }

    /// @inheritdoc ICustody
    function pauseVault()
        external
        override
        onlyOwner
        whenNotPaused
        whenNotFinalized
    {
        _updateGuardianFees();

        execution.claimNow();

        _pause();
    }

    /// @inheritdoc ICustody
    function resumeVault()
        external
        override
        onlyOwner
        whenPaused
        whenNotFinalized
    {
        lastFeeCheckpoint = block.timestamp;

        _unpause();
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
        uint256 numYieldAssets;

        for (uint256 i = 0; i < numAssets; i++) {
            if (assets[i].isERC4626) {
                numYieldAssets++;
            }
        }

        uint256[] memory underlyingTargetWeights = _adjustYieldAssets(
            assets,
            assetWeights
        );
        underlyingTargetWeights = _normalizeWeights(underlyingTargetWeights);

        IExecution.AssetRebalanceRequest[]
            memory requests = new IExecution.AssetRebalanceRequest[](
                numAssets - numYieldAssets
            );

        AssetValue[] memory assetAmounts = _getHoldings(assets);

        IAssetRegistry.AssetInformation memory asset;
        uint256 index;
        for (uint256 i = 0; i < numAssets; i++) {
            asset = assets[i];
            if (!asset.isERC4626) {
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

        rebalanceEndTime = endTime;

        execution.startRebalance(requests, startTime, endTime);

        emit StartRebalance(assetWeights, startTime, endTime);
    }

    /// @inheritdoc ICustody
    function endRebalance()
        external
        override
        nonReentrant
        onlyOwnerOrGuardian
        whenNotPaused
        whenNotFinalized
    {
        if (rebalanceEndTime == 0) {
            revert Aera__RebalancingHasNotStarted();
        }
        if (block.timestamp < rebalanceEndTime) {
            revert Aera__RebalancingIsOnGoing(rebalanceEndTime);
        }

        _updateGuardianFees();

        execution.endRebalance();

        emit EndRebalance();
    }

    /// @inheritdoc ICustody
    function endRebalanceEarly()
        external
        override
        nonReentrant
        onlyOwnerOrGuardian
        whenNotPaused
        whenNotFinalized
    {
        _updateGuardianFees();

        execution.claimNow();

        emit EndRebalanceEarly();
    }

    /// @inheritdoc ICustody
    function claimGuardianFees() external override nonReentrant {
        if (msg.sender == guardian) {
            _updateGuardianFees();
        }

        AssetValue[] storage fees = guardiansFee[msg.sender];
        uint256 numFees = fees.length;

        if (numFees == 0) {
            revert Aera__NoAvailableFeeForCaller(msg.sender);
        }

        AssetValue[] memory claimedFees = new AssetValue[](numFees);
        AssetValue storage fee;
        uint256 availableFee;
        bool allFeesClaimed = true;

        for (uint256 i = 0; i < numFees; i++) {
            fee = fees[i];
            claimedFees[i].asset = fee.asset;

            if (fee.value == 0) {
                continue;
            }

            availableFee = Math.min(
                fee.asset.balanceOf(address(this)),
                fee.value
            );
            guardiansFeeTotal[fee.asset] -= availableFee;
            fee.value -= availableFee;
            fee.asset.safeTransfer(msg.sender, availableFee);
            claimedFees[i].value = availableFee;

            if (fee.value > 0) {
                allFeesClaimed = false;
            }
        }

        if (allFeesClaimed && msg.sender != guardian) {
            delete guardiansFee[msg.sender];
        }

        emit ClaimGuardianFees(msg.sender, claimedFees);
    }

    /// @inheritdoc ICustody
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
    /// @return feeIndex Guardian fee index.
    function _getFeeIndex() internal view returns (uint256 feeIndex) {
        if (block.timestamp > lastFeeCheckpoint) {
            feeIndex = block.timestamp - lastFeeCheckpoint;
        }

        return feeIndex;
    }

    /// @notice Calculate current guardian fees.
    /// @dev Will only be called by withdraw(), setGuardian(), setAssetRegistry(),
    ///      setExecution(), finalize(), pauseVault(), startRebalance(),
    ///      endRebalance(), endRebalanceEarly() and claimGuardianFees().
    function _updateGuardianFees() internal {
        if (guardianFee == 0) {
            return;
        }

        uint256 feeIndex = _getFeeIndex();

        if (feeIndex == 0) {
            return;
        }

        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();
        AssetValue[] memory assetAmounts = _getHoldings(assets);

        lastFeeCheckpoint = block.timestamp;

        uint256 numAssets = assets.length;
        uint256 numGuardiansFee = guardiansFee[guardian].length;
        AssetValue memory assetAmount;
        uint256 newFee;

        for (uint256 i = 0; i < numAssets; i++) {
            assetAmount = assetAmounts[i];
            newFee = (assetAmount.value * feeIndex * guardianFee) / _ONE;
            uint256 j;
            for (; j < numGuardiansFee; j++) {
                if (guardiansFee[guardian][j].asset == assetAmount.asset) {
                    guardiansFee[guardian][j].value += newFee;
                    break;
                }
            }
            if (j == numGuardiansFee) {
                guardiansFee[guardian].push(
                    AssetValue(assetAmount.asset, newFee)
                );
            }

            guardiansFeeTotal[assetAmount.asset] += newFee;
        }
    }

    /// @notice Check request to withdraw.
    /// @dev Will only be called by withdraw().
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
    /// @dev Will only be called by startRebalance().
    /// @param assets Struct details for registered assets in asset registry.
    /// @param assetWeights Struct details for weights of assets.
    /// @return underlyingTargetWeights Total target weights of underlying assets.
    function _adjustYieldAssets(
        IAssetRegistry.AssetInformation[] memory assets,
        AssetValue[] calldata assetWeights
    ) internal returns (uint256[] memory underlyingTargetWeights) {
        uint256 numAssets = assets.length;
        uint256[] memory targetWeights = _getTargetWeights(
            assets,
            assetWeights
        );

        uint256[] memory underlyingIndexes = _getUnderlyingIndexes(assets);
        (
            uint256[] memory spotPrices,
            uint256[] memory assetUnits
        ) = _getSpotPricesAndUnits(assets);

        uint256[] memory depositAmounts = new uint256[](numAssets);
        uint256[] memory withdrawAmounts = new uint256[](numAssets);
        uint256[] memory currentWeights = new uint256[](numAssets);

        (
            depositAmounts,
            withdrawAmounts,
            currentWeights
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
            if (assets[i].isERC4626 && withdrawAmounts[i] > 0) {
                if (
                    _withdrawUnderlyingAsset(
                        assets[i],
                        withdrawAmounts[i],
                        spotPrices[i],
                        assetUnits[i]
                    ) > 0
                ) {
                    underlyingTargetWeights[
                        underlyingIndexes[i]
                    ] -= targetWeights[i];
                } else {
                    underlyingTargetWeights[
                        underlyingIndexes[i]
                    ] -= currentWeights[i];
                }
            }
        }

        AssetValue[] memory assetAmounts = _getHoldings(assets);
        for (uint256 i = 0; i < numAssets; i++) {
            if (assets[i].isERC4626 && depositAmounts[i] > 0) {
                if (
                    assetAmounts[underlyingIndexes[i]].value >
                    depositAmounts[i] &&
                    _depositUnderlyingAsset(
                        assets[i],
                        depositAmounts[i],
                        spotPrices[i],
                        assetUnits[i]
                    ) >
                    0
                ) {
                    assetAmounts[underlyingIndexes[i]].value -= depositAmounts[
                        i
                    ];
                    underlyingTargetWeights[
                        underlyingIndexes[i]
                    ] -= targetWeights[i];
                } else {
                    underlyingTargetWeights[
                        underlyingIndexes[i]
                    ] -= currentWeights[i];
                }
            }
        }
    }

    /// @notice Calculate the amounts of underlying assets of yield assets to adjust.
    /// @dev Will only be called by _adjustYieldAssets().
    /// @param assets Struct details for registered assets in asset registry.
    /// @param targetWeights Reordered target weights.
    /// @param spotPrices Spot prices of assets.
    /// @param assetUnits Units of assets.
    /// @return depositAmounts Amounts of underlying assets to deposit to yield tokens.
    /// @return withdrawAmounts Amounts of underlying assets to withdraw from yield tokens.
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
            uint256[] memory currentWeights
        )
    {
        uint256 numAssets = assets.length;
        depositAmounts = new uint256[](numAssets);
        withdrawAmounts = new uint256[](numAssets);
        currentWeights = new uint256[](numAssets);
        uint256[] memory underlyingBalances = new uint256[](numAssets);
        uint256[] memory values = new uint256[](numAssets);
        AssetValue[] memory assetAmounts = _getHoldings(assets);
        uint256 totalValue = 0;
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

            if (assets[i].isERC4626) {
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
    }

    /// @notice Deposit the amount of underlying asset to yield asset.
    /// @dev Will only be called by _adjustYieldAssets().
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
    /// @dev Will only be called by withdraw() and _adjustYieldAssets().
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
    /// @dev Will only be called by _adjustYieldAssets().
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
    /// @dev Will only be called by startRebalance().
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
            newWeights[0] = newWeights[0] + _ONE - adjustedSum;
        } else if (adjustedSum > _ONE) {
            uint256 deviation = adjustedSum - _ONE;
            for (uint256 i = 0; i < numWeights; i++) {
                if (newWeights[i] > deviation) {
                    newWeights[i] -= deviation;
                }
            }
        }
    }

    /// @notice Get spot prices and units of requested assets.
    /// @dev Will only be called by withdraw() and _adjustYieldAssets().
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
    /// @dev Will only be called by withdraw() and _adjustYieldAssets().
    /// @param assets Struct details for registered assets in asset registry.
    /// @return underlyingIndexes Array of underlying asset indexes.
    function _getUnderlyingIndexes(
        IAssetRegistry.AssetInformation[] memory assets
    ) internal view returns (uint256[] memory underlyingIndexes) {
        uint256 numAssets = assets.length;
        underlyingIndexes = new uint256[](numAssets);

        for (uint256 i = 0; i < numAssets; i++) {
            if (assets[i].isERC4626) {
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
    }

    /// @notice Get total amount of assets in execution and custody module.
    /// @dev Will only be called by startRebalance(), finalize(), holdings(),
    ///     _updateGuardianFees(), _checkWithdrawRequest(), _calcAdjustmentAmounts()
    ///     and _adjustYieldAssets().
    /// @param assets Struct details for registered assets in asset registry.
    /// @return assetAmounts Amount of assets.
    function _getHoldings(
        IAssetRegistry.AssetInformation[] memory assets
    ) internal view returns (AssetValue[] memory assetAmounts) {
        IExecution.AssetValue[] memory executionHoldings = execution.holdings();

        uint256 numAssets = assets.length;
        uint256 numExecutionHoldings = executionHoldings.length;

        assetAmounts = new AssetValue[](numAssets);
        IAssetRegistry.AssetInformation memory asset;

        for (uint256 i = 0; i < numAssets; i++) {
            asset = assets[i];
            assetAmounts[i] = AssetValue({
                asset: asset.asset,
                value: asset.asset.balanceOf(address(this))
            });
            if (guardiansFeeTotal[asset.asset] > 0) {
                assetAmounts[i].value -= guardiansFeeTotal[asset.asset];
            }
        }

        IExecution.AssetValue memory executionHolding;

        for (uint256 i = 0; i < numExecutionHoldings; i++) {
            executionHolding = executionHoldings[i];

            for (uint256 j = 0; j < numAssets; j++) {
                if (assets[j].asset < executionHolding.asset) {
                    continue;
                }
                if (assets[j].asset == executionHolding.asset) {
                    assetAmounts[j].value += executionHolding.value;
                }
                break;
            }
        }
    }

    /// @notice Reset allowance of token for a spender.
    /// @dev Will only be called by _depositUnderlyingAsset() and _setAllowance().
    /// @param token Token of address to set allowance.
    /// @param spender Address to give spend approval to.
    function _clearAllowance(IERC20 token, address spender) internal {
        uint256 allowance = token.allowance(address(this), spender);
        if (allowance > 0) {
            token.safeDecreaseAllowance(spender, allowance);
        }
    }

    /// @notice Set allowance of token for a spender.
    /// @dev Will only be called by startRebalance() and _depositUnderlyingAsset().
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
    /// @dev Will only be called by constructor and setGuardian().
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
    ) internal view {
        if (newAssetRegistry == address(0)) {
            revert Aera__AssetRegistryIsZeroAddress();
        }
        if (
            !ERC165Checker.supportsInterface(
                newAssetRegistry,
                type(IAssetRegistry).interfaceId
            )
        ) {
            revert Aera__AssetRegistryIsNotValid(newAssetRegistry);
        }
    }

    /// @notice Check if the address can be an execution.
    /// @dev Will only be called by constructor and setExecution()
    /// @param newExecution Address to check.
    function _checkExecutionAddress(address newExecution) internal view {
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

    /// @notice Check whether asset is registered to asset registry or not.
    /// @dev Will only be called by deposit(), sweep(), _checkWithdrawRequest()
    ///      and _getTargetWeights().
    /// @param asset Asset to check.
    /// @param registeredAssets Array of registered assets.
    /// @return isRegistered True if asset is registered.
    /// @return index Index of asset in Balancer pool.
    function _isAssetRegistered(
        IERC20 asset,
        IAssetRegistry.AssetInformation[] memory registeredAssets
    ) internal pure returns (bool isRegistered, uint256 index) {
        uint256 numAssets = registeredAssets.length;

        for (uint256 i = 0; i < numAssets; i++) {
            if (registeredAssets[i].asset < asset) {
                continue;
            }
            if (registeredAssets[i].asset == asset) {
                return (true, i);
            }
            break;
        }
    }
}
