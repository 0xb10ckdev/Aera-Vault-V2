// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./dependencies/openzeppelin/IERC4626.sol";
import "./dependencies/openzeppelin/Math.sol";
import "./dependencies/openzeppelin/Ownable.sol";
import "./dependencies/openzeppelin/ReentrancyGuard.sol";
import "./dependencies/openzeppelin/SafeERC20.sol";
import "./interfaces/IAssetRegistry.sol";
import "./interfaces/ICustody.sol";
import "./interfaces/IExecution.sol";

/// @title Aera Vault V2.
contract AeraVaultV2 is ICustody, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 internal constant _ONE = 1e18;

    /// @notice Largest management fee earned proportion per one second.
    /// @dev 0.0000001% per second, i.e. 3.1536% per year.
    ///      0.0000001% * (365 * 24 * 60 * 60) = 3.1536%
    uint256 private constant _MAX_GUARDIAN_FEE = 10 ** 9;

    /// @notice Guardian fee per second in 18 decimal fixed point format.
    uint256 public immutable guardianFee;

    /// @notice Minimum action threshold for yield bearing assets measured in base token terms.
    uint256 public immutable minYieldActionThreshold;

    /// STORAGE ///

    /// @notice The address of asset registry.
    IAssetRegistry public assetRegistry;

    /// @notice The address of execution module.
    IExecution public execution;

    /// @notice The address of guardian.
    address public guardian;

    /// @notice Whether custody module is paused or not.
    bool public isPaused;

    /// @notice Fee earned amount for each guardian.
    mapping(address => AssetValue[]) public guardiansFee;

    /// @notice Total guardian fee earned amount.
    mapping(IERC20 => uint256) public guardiansFeeTotal;

    /// @notice Last timestamp where guardian fee index was locked.
    uint256 public lastFeeCheckpoint = type(uint256).max;

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

    /// @dev Throws if called after the vault is paused.
    modifier whenNotPaused() {
        if (isPaused) {
            revert Aera__VaultIsPaused();
        }
        _;
    }

    /// @dev Throws if called after the vault is resumed.
    modifier whenPaused() {
        if (!isPaused) {
            revert Aera__VaultIsNotPaused();
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
    /// @param assetRegistry_ The address of asset registry.
    /// @param execution_ The address of execution module.
    /// @param guardian_ The address of guardian.
    /// @param guardianFee_ Guardian fee per second in 18 decimal fixed point format.
    /// @param minYieldActionThreshold_ Minimum action threshold for yield bearing assets
    ///                                 measured in base token terms.
    constructor(
        address assetRegistry_,
        address execution_,
        address guardian_,
        uint256 guardianFee_,
        uint256 minYieldActionThreshold_
    ) {
        _checkAssetRegistryAddress(assetRegistry_);
        _checkExecutionAddress(execution_);
        _checkGuardianAddress(guardian_);

        if (guardianFee_ > _MAX_GUARDIAN_FEE) {
            revert Aera__GuardianFeeIsAboveMax(guardianFee_, _MAX_GUARDIAN_FEE);
        }
        if (minYieldActionThreshold_ == 0) {
            revert Aera__MinYieldActionThresholdIsZero();
        }

        assetRegistry = IAssetRegistry(assetRegistry_);
        execution = IExecution(execution_);
        guardian = guardian_;
        guardianFee = guardianFee_;
        minYieldActionThreshold = minYieldActionThreshold_;
        lastFeeCheckpoint = block.timestamp;

        emit SetAssetRegistry(assetRegistry_);
        emit SetExecution(execution_);
        emit SetGuardian(guardian_);
    }

    /// @inheritdoc ICustody
    function deposit(
        AssetValue[] memory amounts
    ) external override nonReentrant onlyOwner {
        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();
        uint256 numAssets = assets.length;
        uint256 numAmounts = amounts.length;
        bool isRegistered;

        for (uint256 i = 0; i < numAmounts; i++) {
            (isRegistered, ) = _isAssetRegistered(
                amounts[i].asset,
                assets,
                numAssets
            );

            if (!isRegistered) {
                revert Aera__AssetIsNotRegistered(amounts[i].asset);
            }

            amounts[i].asset.safeTransferFrom(
                owner(),
                address(this),
                amounts[i].value
            );
        }

        emit Deposit(amounts);
    }

    /// @inheritdoc ICustody
    function withdraw(
        AssetValue[] memory amounts,
        bool force
    ) external override nonReentrant onlyOwner {
        _updateGuardianFees();

        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();
        AssetValue[] memory assetAmounts = _getHoldings(assets);

        uint256 numAssets = assets.length;
        uint256 numAmounts = amounts.length;
        bool isRegistered;
        uint256 index;

        for (uint256 i = 0; i < numAmounts; i++) {
            (isRegistered, index) = _isAssetRegistered(
                amounts[i].asset,
                assets,
                numAssets
            );

            if (isRegistered) {
                if (assetAmounts[index].value < amounts[i].value) {
                    revert Aera__AmountExceedsAvailable(
                        amounts[i].asset,
                        amounts[i].value,
                        assetAmounts[i].value
                    );
                }
            } else {
                revert Aera__AssetIsNotRegistered(amounts[i].asset);
            }
        }

        bool claimed;

        for (uint256 i = 0; i < numAmounts; i++) {
            if (
                !claimed &&
                amounts[i].asset.balanceOf(address(this)) < amounts[i].value
            ) {
                if (!force) {
                    revert Aera__AmountExceedsAvailable(
                        amounts[i].asset,
                        amounts[i].value,
                        amounts[i].asset.balanceOf(address(this))
                    );
                }

                execution.claimNow();
                claimed = true;
            }

            if (amounts[i].value > 0) {
                amounts[i].asset.safeTransfer(owner(), amounts[i].value);
            }
        }

        emit Withdraw(amounts, force);
    }

    /// @inheritdoc ICustody
    function setGuardian(address newGuardian) external override onlyOwner {
        _checkGuardianAddress(newGuardian);
        _updateGuardianFees();

        guardian = newGuardian;

        emit SetGuardian(newGuardian);
    }

    /// @inheritdoc ICustody
    function setAssetRegistry(
        address newAssetRegistry
    ) external override onlyOwner {
        _checkAssetRegistryAddress(newAssetRegistry);
        _updateGuardianFees();

        assetRegistry = IAssetRegistry(newAssetRegistry);

        emit SetAssetRegistry(newAssetRegistry);
    }

    /// @inheritdoc ICustody
    function setExecution(address newExecution) external override onlyOwner {
        _checkExecutionAddress(newExecution);
        _updateGuardianFees();

        execution = IExecution(newExecution);

        emit SetExecution(newExecution);
    }

    /// @inheritdoc ICustody
    function finalize() external override onlyOwner {
        _updateGuardianFees();

        execution.claimNow();

        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();
        AssetValue[] memory assetAmounts = _getHoldings(assets);
        uint256 numAssetAmounts = assetAmounts.length;

        for (uint256 i = 0; i < numAssetAmounts; i++) {
            assetAmounts[i].asset.safeTransfer(owner(), assetAmounts[i].value);
        }

        emit Finalize();
    }

    /// @inheritdoc ICustody
    function sweep(
        IERC20 token,
        uint256 amount
    ) external override nonReentrant {
        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();
        uint256 numAssets = assets.length;

        (bool isRegistered, ) = _isAssetRegistered(token, assets, numAssets);

        if (isRegistered) {
            revert Aera__CannotSweepRegisteredAsset();
        }

        token.safeTransfer(owner(), amount);

        emit Sweep(token, amount);
    }

    /// @inheritdoc ICustody
    function pauseVault() external override onlyOwner whenNotPaused {
        _updateGuardianFees();

        execution.claimNow();
        isPaused = true;

        emit PauseVault();
    }

    /// @inheritdoc ICustody
    function resumeVault() external override onlyOwner whenPaused {
        lastFeeCheckpoint = block.timestamp;
        isPaused = false;

        emit ResumeVault();
    }

    /// @inheritdoc ICustody
    function startRebalance(
        AssetValue[] calldata assetWeights,
        uint256 startTime,
        uint256 endTime
    ) external override nonReentrant onlyGuardian whenNotPaused {
        _updateGuardianFees();

        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();
        uint256 numAssets = assets.length;

        uint256[] memory underlyingTargetWeights = _adjustYieldAssets(
            assets,
            assetWeights
        );
        underlyingTargetWeights = _normalizeWeights(underlyingTargetWeights);

        IExecution.AssetRebalanceRequest[]
            memory requests = new IExecution.AssetRebalanceRequest[](
                numAssets - assetRegistry.numYieldAssets()
            );

        AssetValue[] memory assetAmounts = _getHoldings(assets);

        uint256 index;
        for (uint256 i = 0; i < numAssets; i++) {
            if (!assets[i].isERC4626) {
                requests[index] = IExecution.AssetRebalanceRequest(
                    assets[i].asset,
                    assetAmounts[i].value,
                    underlyingTargetWeights[i]
                );
                _setAllowance(
                    assets[i].asset,
                    address(execution),
                    assetAmounts[i].value
                );
                index++;
            }
        }

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
    {
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

        if (guardiansFee[msg.sender].length == 0) {
            revert Aera__NoAvailableFeeForCaller(msg.sender);
        }

        AssetValue[] memory fees = guardiansFee[msg.sender];
        uint256 numFees = fees.length;
        AssetValue[] memory claimedFees = new AssetValue[](numFees);
        uint256 availableFee;
        bool allFeeClaimed = true;

        for (uint256 i = 0; i < numFees; i++) {
            claimedFees[i].asset = fees[i].asset;

            if (fees[i].value == 0) {
                continue;
            }

            availableFee = Math.min(
                fees[i].asset.balanceOf(address(this)),
                fees[i].value
            );
            guardiansFeeTotal[fees[i].asset] -= availableFee;
            guardiansFee[msg.sender][i].value -= availableFee;
            fees[i].asset.safeTransfer(msg.sender, availableFee);
            claimedFees[i].value = availableFee;

            if (guardiansFee[msg.sender][i].value > 0) {
                allFeeClaimed = false;
            }
        }

        if (allFeeClaimed && msg.sender != guardian) {
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
    ///      setExecution(), finalize(), startRebalance(), endRebalance(),
    ///      endRebalanceEarly() and claimGuardianFees().
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
        uint256 newFee;

        for (uint256 i = 0; i < numAssets; i++) {
            newFee = (assetAmounts[i].value * feeIndex * guardianFee) / _ONE;
            uint256 j;
            for (; j < numGuardiansFee; j++) {
                if (guardiansFee[guardian][j].asset == assetAmounts[i].asset) {
                    guardiansFee[guardian][j].value += newFee;
                    break;
                }
            }
            if (j == numGuardiansFee) {
                guardiansFee[guardian].push(
                    AssetValue(assetAmounts[i].asset, newFee)
                );
            }

            guardiansFeeTotal[assetAmounts[i].asset] += newFee;
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
        uint256[] memory targetWeights = _getTargatWeights(
            assets,
            assetWeights
        );

        uint256[] memory underlyingIndexes = _getUnderlyingIndexes(assets);
        (
            uint256[] memory spotPrices,
            uint256[] memory assetUnits
        ) = _getSpotPricesAndUnits(assets);

        uint256[] memory underlyingBalances = new uint256[](numAssets);
        uint256[] memory depositAmounts = new uint256[](numAssets);
        underlyingTargetWeights = new uint256[](numAssets);

        AssetValue[] memory assetAmounts = _getHoldings(assets);

        {
            uint256 totalValue = 0;
            {
                uint256 balance;
                for (uint256 i = 0; i < numAssets; i++) {
                    if (assets[i].isERC4626) {
                        balance = IERC4626(address(assets[i].asset))
                            .convertToAssets(assetAmounts[i].value);
                        underlyingBalances[i] = balance;
                        underlyingTargetWeights[
                            underlyingIndexes[i]
                        ] += targetWeights[i];
                    } else {
                        balance = assetAmounts[i].value;
                        underlyingTargetWeights[i] += targetWeights[i];
                    }

                    totalValue += (balance * spotPrices[i]) / assetUnits[i];
                }
            }

            uint256 targetBalance;
            uint256 withdrawalAmount;
            for (uint256 i = 0; i < numAssets; i++) {
                if (assets[i].isERC4626) {
                    targetBalance =
                        (totalValue * targetWeights[i] * assetUnits[i]) /
                        spotPrices[i] /
                        _ONE;
                    if (targetBalance > underlyingBalances[i]) {
                        depositAmounts[i] =
                            targetBalance -
                            underlyingBalances[i];
                    } else {
                        withdrawalAmount =
                            underlyingBalances[i] -
                            targetBalance;
                        if (
                            (withdrawalAmount * spotPrices[i]) /
                                assetUnits[i] >=
                            minYieldActionThreshold
                        ) {
                            IERC4626(address(assets[i].asset)).withdraw(
                                underlyingBalances[i] - targetBalance,
                                address(this),
                                address(this)
                            );
                            underlyingTargetWeights[
                                underlyingIndexes[i]
                            ] -= targetWeights[i];
                        }
                    }
                }
            }
        }

        assetAmounts = _getHoldings(assets);
        for (uint256 i = 0; i < numAssets; i++) {
            if (assets[i].isERC4626 && depositAmounts[i] > 0) {
                if (
                    assetAmounts[underlyingIndexes[i]].value >
                    depositAmounts[i] &&
                    (depositAmounts[i] * spotPrices[i]) / assetUnits[i] >=
                    minYieldActionThreshold
                ) {
                    _setAllowance(
                        IERC20(IERC4626(address(assets[i].asset)).asset()),
                        address(assets[i].asset),
                        depositAmounts[i]
                    );
                    IERC4626(address(assets[i].asset)).deposit(
                        depositAmounts[i],
                        address(this)
                    );
                    assetAmounts[underlyingIndexes[i]].value -= depositAmounts[
                        i
                    ];
                    underlyingTargetWeights[
                        underlyingIndexes[i]
                    ] -= targetWeights[i];
                }
            }
        }
    }

    /// @notice Get target weights in registered asset order.
    /// @dev Will only be called by _adjustYieldAssets().
    /// @param assets Struct details for registered assets in asset registry.
    /// @param assetWeights Struct details for weights of assets.
    /// @return targetWeights Reordered target weights.
    function _getTargatWeights(
        IAssetRegistry.AssetInformation[] memory assets,
        AssetValue[] calldata assetWeights
    ) internal pure returns (uint256[] memory targetWeights) {
        uint256 numAssets = assets.length;
        uint256 numAssetWeights = assetWeights.length;

        if (numAssets != numAssetWeights) {
            revert Aera__ValueLengthIsNotSame(numAssets, numAssetWeights);
        }

        targetWeights = new uint256[](numAssetWeights);

        bool isRegistered;
        uint256 index;
        uint256 weightSum = 0;

        for (uint256 i = 0; i < numAssetWeights; i++) {
            (isRegistered, index) = _isAssetRegistered(
                assetWeights[i].asset,
                assets,
                numAssets
            );

            if (!isRegistered) {
                revert Aera__AssetIsNotRegistered(assetWeights[i].asset);
            }

            targetWeights[index] = assetWeights[i].value;
            weightSum += assetWeights[i].value;

            for (uint256 j = 0; j < numAssetWeights; j++) {
                if (i != j && assetWeights[i].asset == assetWeights[j].asset) {
                    revert Aera__AssetIsDuplicated(assetWeights[i].asset);
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
            newWeights[i] = (weights[i] * _ONE) / weightSum;
            adjustedSum += newWeights[i];
        }

        newWeights[0] = newWeights[0] + _ONE - adjustedSum;
    }

    /// @notice Get spot prices and units of requested assets.
    /// @dev Will only be called by _adjustYieldAssets().
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

        address underlyingAsset;

        for (uint256 i = 0; i < numAssets; i++) {
            if (assets[i].isERC4626) {
                underlyingAsset = IERC4626(address(assets[i].asset)).asset();
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
                    if (assets[i].asset == erc20SpotPrices[j].asset) {
                        spotPrices[i] = erc20SpotPrices[j].spotPrice;
                        break;
                    }
                }

                assetUnits[i] =
                    10 ** IERC20Metadata(address(assets[i].asset)).decimals();
            }
        }
    }

    /// @notice Returns an array of underlying asset indexes.
    /// @dev Will only be called by _adjustYieldAssets().
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
    /// @dev Will only be called by withdraw(), finalize(), startRebalance(),
    ///      holdings() and _updateGuardianFees().
    /// @param assets Struct details for registered assets in asset registry.
    /// @return assetAmounts Amount of assets.
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
            if (guardiansFeeTotal[assets[i].asset] > 0) {
                assetAmounts[i].value -= guardiansFeeTotal[assets[i].asset];
            }
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
    /// @dev Will only be called by _setAllowance().
    /// @param token Token of address to set allowance.
    /// @param spender Address to give spend approval to.
    function _clearAllowance(IERC20 token, address spender) internal {
        uint256 allowance = token.allowance(address(this), spender);
        if (allowance > 0) {
            token.safeDecreaseAllowance(spender, allowance);
        }
    }

    /// @notice Set allowance of token for a spender.
    /// @dev Will only be called by startRebalance().
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

    /// @notice Check whether asset is registered to asset registry or not.
    /// @dev Will only be called by deposit(), withdraw(), sweep() and startRebalance().
    /// @param asset Asset to check.
    /// @param registeredAssets Array of registered assets.
    /// @param numAssets Number of registered assets.
    /// @return isRegistered True if asset is registered.
    /// @return index Index of asset in Balancer pool.
    function _isAssetRegistered(
        IERC20 asset,
        IAssetRegistry.AssetInformation[] memory registeredAssets,
        uint256 numAssets
    ) internal pure returns (bool isRegistered, uint256 index) {
        for (uint256 i = 0; i < numAssets; i++) {
            if (registeredAssets[i].asset < asset) {
                continue;
            } else if (registeredAssets[i].asset == asset) {
                isRegistered = true;
                index = i;
                break;
            } else {
                break;
            }
        }
    }
}
