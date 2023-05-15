// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./dependencies/openzeppelin/ERC165.sol";
import "./dependencies/openzeppelin/IERC20Metadata.sol";
import "./dependencies/openzeppelin/Math.sol";
import "./dependencies/openzeppelin/Ownable.sol";
import "./dependencies/openzeppelin/ReentrancyGuard.sol";
import "./dependencies/openzeppelin/SafeERC20.sol";
import "./interfaces/IBalancerExecution.sol";
import "./interfaces/IBManagedPool.sol";
import "./interfaces/IBManagedPoolFactory.sol";
import "./interfaces/IBMerkleOrchard.sol";
import "./interfaces/IBVault.sol";

/// @title Aera Balancer Execution.
contract AeraBalancerExecution is
    IBalancerExecution,
    ERC165,
    Ownable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    uint256 internal constant _ONE = 1e18;

    /// @notice Mininum weight of pool tokens in Balancer Pool.
    uint256 private constant _MIN_WEIGHT = 0.01e18;

    /// @notice The address of asset registry.
    IAssetRegistry public immutable assetRegistry;

    /// @notice Balancer Vault.
    IBVault public immutable bVault;

    /// @notice Balancer Managed Pool.
    IBManagedPool public immutable pool;

    /// @notice Pool ID of underlying Balancer Pool.
    bytes32 public immutable poolId;

    /// @notice Balancer Merkle Orchard.
    IBMerkleOrchard public immutable merkleOrchard;

    /// STORAGE ///

    /// @notice Describes execution module and which custody vault it is intended for.
    /// @dev string cannot be immutable bytecode but only set in constructor.
    string public description;

    /// @notice Vault contract that the execution layer is linked to.
    address public vault;

    /// @notice Timestamp at when rebalancing ends.
    uint256 public rebalanceEndTime;

    /// ERRORS ///

    error Aera__DescriptionIsEmpty();
    error Aera__PoolTokenIsNotRegistered(IERC20 poolToken);
    error Aera__ModuleIsAlreadyInitialized();
    error Aera__VaultIsZeroAddress();
    error Aera__WeightIsBelowMin(uint256 actual, uint256 min);
    error Aera__CannotSweepPoolAsset();

    /// MODIFIERS ///

    /// @dev Throws if called by any account other than the vault.
    modifier onlyVault() {
        if (msg.sender != vault) {
            revert Aera__CallerIsNotVault();
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
    /// @param vaultParams Struct vault parameter.
    constructor(NewBalancerExecutionParams memory vaultParams) {
        if (vaultParams.assetRegistry == address(0)) {
            revert Aera__AssetRegistryIsZeroAddress();
        }

        if (bytes(vaultParams.description).length == 0) {
            revert Aera__DescriptionIsEmpty();
        }

        IAssetRegistry.AssetInformation[] memory assets = IAssetRegistry(
            vaultParams.assetRegistry
        ).assets();

        uint256 numPoolTokens = vaultParams.poolTokens.length;
        uint256 numAssets = assets.length;
        address[] memory assetManagers = new address[](numPoolTokens);
        uint256 assetIndex = 0;

        for (uint256 i = 0; i < numPoolTokens; i++) {
            for (; assetIndex < numAssets; assetIndex++) {
                if (
                    vaultParams.poolTokens[i] == assets[assetIndex].asset &&
                    !assets[assetIndex].isERC4626
                ) {
                    break;
                }
            }

            if (assetIndex == numAssets) {
                revert Aera__PoolTokenIsNotRegistered(
                    vaultParams.poolTokens[i]
                );
            }

            assetManagers[i] = address(this);
        }

        // Deploys a new ManagedPool from ManagedPoolFactory
        // create(
        //     ManagedPool.NewPoolParams memory poolParams,
        //     address owner,
        // )
        //
        // - poolParams.mustAllowlistLPs should be true to prevent other accounts
        //   to use joinPool
        pool = IBManagedPool(
            IBManagedPoolFactory(vaultParams.factory).create(
                IBManagedPoolFactory.NewPoolParams({
                    name: vaultParams.name,
                    symbol: vaultParams.symbol,
                    tokens: vaultParams.poolTokens,
                    normalizedWeights: vaultParams.weights,
                    assetManagers: assetManagers,
                    swapFeePercentage: vaultParams.swapFeePercentage,
                    swapEnabledOnStart: false,
                    mustAllowlistLPs: true,
                    managementAumFeePercentage: 0,
                    aumFeeId: 0
                }),
                address(this)
            )
        );
        pool.addAllowedAddress(address(this));

        bVault = pool.getVault();
        poolId = pool.getPoolId();
        description = vaultParams.description;
        assetRegistry = IAssetRegistry(vaultParams.assetRegistry);
        merkleOrchard = IBMerkleOrchard(vaultParams.merkleOrchard);
    }

    /// @inheritdoc IBalancerExecution
    function initialize(
        address vault_
    ) external override nonReentrant onlyOwner {
        if (vault != address(0)) {
            revert Aera__ModuleIsAlreadyInitialized();
        }

        if (vault_ == address(0)) {
            revert Aera__VaultIsZeroAddress();
        }

        vault = vault_;

        IERC20[] memory poolTokens = _getPoolTokens();
        uint256 numPoolTokens = poolTokens.length;
        uint256[] memory balances = new uint256[](numPoolTokens);
        uint256[] memory maxAmountsIn = new uint256[](numPoolTokens + 1);

        maxAmountsIn[0] = type(uint256).max;
        for (uint256 i = 0; i < numPoolTokens; i++) {
            poolTokens[i].safeTransferFrom(owner(), address(this), 1);
            _setAllowance(poolTokens[i], address(bVault), 1);

            balances[i] = 1;
            maxAmountsIn[i + 1] = 1;
        }

        bytes memory initUserData = abi.encode(IBVault.JoinKind.INIT, balances);

        IERC20[] memory tokens;
        (tokens, , ) = bVault.getPoolTokens(poolId);
        IBVault.JoinPoolRequest memory joinPoolRequest = IBVault
            .JoinPoolRequest({
                assets: tokens,
                maxAmountsIn: maxAmountsIn,
                userData: initUserData,
                fromInternalBalance: false
            });

        bVault.joinPool(poolId, address(this), address(this), joinPoolRequest);

        pool.setSwapEnabled(true);

        emit Initialize(vault);
    }

    /// @inheritdoc IExecution
    function startRebalance(
        AssetRebalanceRequest[] calldata requests,
        uint256 startTime,
        uint256 endTime
    ) external override nonReentrant onlyVault {
        if (rebalanceEndTime > 0) {
            revert Aera__RebalancingIsOnGoing(rebalanceEndTime);
        }

        _validateRequests(requests, startTime, endTime);

        (
            IAssetRegistry.AssetPriceReading[] memory spotPrices,
            uint256[] memory assetUnits
        ) = _getSpotPricesAndUnits(requests);

        (
            uint256[] memory startAmounts,
            uint256[] memory endAmounts,
            uint256 adjustableAssetValue,
            uint256 necessaryTotalValue
        ) = _calcAmountsAndValues(requests, spotPrices, assetUnits);

        uint256 numRequests = requests.length;
        uint256[] memory startWeights = new uint256[](numRequests);
        uint256[] memory endWeights = new uint256[](numRequests);

        {
            // It is an amount of asset that will not participate in the rebalancing.
            uint256 adjustableAmount;
            uint256 spotPrice;
            uint256 assetUnit;
            for (uint256 i = 0; i < numRequests; i++) {
                spotPrice = spotPrices[i].spotPrice;
                assetUnit = assetUnits[i];
                adjustableAmount =
                    (adjustableAssetValue * assetUnit) /
                    spotPrice;
                if (startAmounts[i] != 0) {
                    startAmounts[i] -= adjustableAmount;
                    startWeights[i] =
                        (startAmounts[i] * spotPrice * _ONE) /
                        necessaryTotalValue /
                        assetUnit;
                    if (startWeights[i] < _MIN_WEIGHT) {
                        startWeights[i] = _MIN_WEIGHT;
                    }
                }
                if (endAmounts[i] != 0) {
                    endAmounts[i] -= adjustableAmount;
                    endWeights[i] =
                        (endAmounts[i] * spotPrice * _ONE) /
                        necessaryTotalValue /
                        assetUnit;
                    if (endWeights[i] < _MIN_WEIGHT) {
                        endWeights[i] = _MIN_WEIGHT;
                    }
                }
            }
        }

        IERC20[] memory rebalancingAssets;
        (
            rebalancingAssets,
            startAmounts,
            startWeights,
            endWeights
        ) = _getValidRebalanceData(
            requests,
            startAmounts,
            startWeights,
            endWeights
        );

        _adjustPool(rebalancingAssets, startAmounts);

        IERC20[] memory poolTokens = _getPoolTokens();

        rebalanceEndTime = endTime;

        pool.updateWeightsGradually(
            block.timestamp,
            block.timestamp,
            poolTokens,
            startWeights
        );

        pool.updateWeightsGradually(startTime, endTime, poolTokens, endWeights);

        emit StartRebalance(requests, startTime, endTime);
    }

    /// @inheritdoc IExecution
    function endRebalance() external override nonReentrant onlyVault {
        if (rebalanceEndTime == 0) {
            revert Aera__RebalancingHasNotStarted();
        }
        if (block.timestamp < rebalanceEndTime) {
            revert Aera__RebalancingIsOnGoing(rebalanceEndTime);
        }

        _claim();

        emit EndRebalance();
    }

    /// @inheritdoc IExecution
    function claimNow() external override nonReentrant onlyVault {
        _claim();

        emit ClaimNow();
    }

    /// @inheritdoc IBalancerExecution
    function claimRewards(
        IBMerkleOrchard.Claim[] calldata claims,
        IERC20[] calldata tokens
    ) external override nonReentrant onlyOwner {
        merkleOrchard.claimDistributions(owner(), claims, tokens);
    }

    /// @inheritdoc IExecution
    function sweep(
        IERC20 token,
        uint256 amount
    ) external override nonReentrant {
        (IERC20[] memory poolAssets, , ) = bVault.getPoolTokens(poolId);
        uint256 numPoolAssets = poolAssets.length;

        for (uint256 i = 0; i < numPoolAssets; i++) {
            if (token == poolAssets[i]) {
                revert Aera__CannotSweepPoolAsset();
            }
        }

        token.safeTransfer(owner(), amount);

        emit Sweep(token, amount);
    }

    /// @inheritdoc IBalancerExecution
    function assets() public view override returns (IERC20[] memory assets) {
        assets = _getPoolTokens();
    }

    /// @inheritdoc IExecution
    function holdings()
        public
        view
        override
        returns (AssetValue[] memory holdings)
    {
        (
            IERC20[] memory poolTokens,
            uint256[] memory poolHoldings
        ) = _getPoolTokensData();
        uint256 numPoolTokens = poolTokens.length;
        holdings = new AssetValue[](numPoolTokens);

        for (uint256 i = 0; i < numPoolTokens; i++) {
            holdings[i] = AssetValue({
                asset: poolTokens[i],
                value: poolHoldings[i]
            });
        }
    }

    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view override returns (bool) {
        return
            interfaceId == type(IBalancerExecution).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    /// INTERNAL FUNCTIONS ///

    /// @notice Claim all funds from Balancer Pool.
    /// @dev Will only be called by endRebalance() and claimNow().
    function _claim() internal {
        (
            IERC20[] memory poolTokens,
            uint256[] memory poolHoldings
        ) = _getPoolTokensData();
        uint256 numPoolTokens = poolTokens.length;

        for (uint256 i = 0; i < numPoolTokens; i++) {
            _withdrawTokenFromPool(poolTokens[i], poolHoldings[i]);
            poolTokens[i].safeTransfer(vault, poolHoldings[i]);
        }

        rebalanceEndTime = 0;
    }

    /// @notice Check if the requests are valid.
    /// @dev Will only be called by startRebalance().
    /// @param requests Struct details for requests.
    /// @param startTime Timestamp at which weight movement should start.
    /// @param endTime Timestamp at which the weights should reach target values.
    function _validateRequests(
        AssetRebalanceRequest[] calldata requests,
        uint256 startTime,
        uint256 endTime
    ) internal view {
        uint256 numRequests = requests.length;
        uint256 weightSum = 0;
        for (uint256 i = 0; i < numRequests; i++) {
            weightSum += requests[i].weight;
        }

        if (weightSum != _ONE) {
            revert Aera__SumOfWeightsIsNotOne();
        }

        startTime = Math.max(block.timestamp, startTime);
        if (startTime > endTime) {
            revert Aera__WeightChangeEndBeforeStart();
        }
    }

    /// @notice Get spot prices and units of requested assets.
    /// @dev Will only be called by startRebalance().
    /// @param requests Each request specifies amount of asset to rebalance and target weight.
    /// @return spotPrices Spot prices of assets.
    /// @return assetUnits Units of assets.
    function _getSpotPricesAndUnits(
        AssetRebalanceRequest[] calldata requests
    )
        internal
        view
        returns (
            IAssetRegistry.AssetPriceReading[] memory spotPrices,
            uint256[] memory assetUnits
        )
    {
        IAssetRegistry.AssetPriceReading[]
            memory assetSpotPrices = assetRegistry.spotPrices();

        uint256 numRequests = requests.length;
        uint256 numAssetSpotPrices = assetSpotPrices.length;

        spotPrices = new IAssetRegistry.AssetPriceReading[](numRequests);
        assetUnits = new uint256[](numRequests);

        for (uint256 i = 0; i < numRequests; i++) {
            assetUnits[i] =
                10 ** IERC20Metadata(address(requests[i].asset)).decimals();

            // It will revert with division by 0 error
            // when there's no match since price is 0.
            for (uint256 j = 0; j < numAssetSpotPrices; j++) {
                if (requests[i].asset == assetSpotPrices[j].asset) {
                    spotPrices[i] = assetSpotPrices[j];
                    break;
                }
            }
        }
    }

    /// @notice Register a token to Balancer pool and deposit to the pool.
    /// @dev Will only be called by _adjustPool().
    /// @param token Token to register.
    /// @param amount Amount to deposit.
    function _bindAndDepositToken(IERC20 token, uint256 amount) internal {
        pool.addToken(token, address(this), _MIN_WEIGHT, 0, address(this));

        _depositTokenToPool(token, amount);
    }

    /// @notice Withdraw a token from Balancer pool and unregister from the pool.
    /// @dev Will only be called by _adjustPool().
    /// @param token Token to unregister.
    /// @param amount Amount to withdraw.
    function _unbindAndWithdrawToken(IERC20 token, uint256 amount) internal {
        _withdrawTokenFromPool(token, amount);

        pool.removeToken(token, 0, address(this));
    }

    /// @notice Deposit token from Execution module to Balancer Pool.
    /// @dev Will only be called by _bindAndDepositTokens().
    /// @param token The token to deposit.
    /// @param amount The amount of token to deposit.
    function _depositTokenToPool(IERC20 token, uint256 amount) internal {
        _setAllowance(token, address(bVault), amount);

        // Set managed balance of token as amount
        // i.e. Deposit amount of token to pool from Execution module
        _updatePoolBalance(token, amount, IBVault.PoolBalanceOpKind.UPDATE);
        // Decrease managed balance and increase cash balance of the token in the pool
        // i.e. Move amount from managed balance to cash balance
        _updatePoolBalance(token, amount, IBVault.PoolBalanceOpKind.DEPOSIT);
    }

    /// @notice Withdraw token from Balancer Pool to Execution module.
    /// @dev Will only be called by _unbindAndWithdrawTokens().
    /// @param token The token to withdraw.
    /// @param amount The amount of token to withdraw.
    function _withdrawTokenFromPool(IERC20 token, uint256 amount) internal {
        // Decrease cash balance and increase managed balance of the pool
        // i.e. Move amount from cash balance to managed balance
        // and withdraw token amount from the pool to Execution module
        _updatePoolBalance(token, amount, IBVault.PoolBalanceOpKind.WITHDRAW);
        // Set managed balance of pool to zero
        _updatePoolBalance(token, 0, IBVault.PoolBalanceOpKind.UPDATE);
    }

    /// @notice Update token balance of Balancer Pool.
    /// @dev Will only be called by _depositTokenToPool() and _withdrawTokenFromPool().
    /// @param token Address of pool token.
    /// @param amount Amount of pool token.
    /// @param kind Kind of pool balance operation.
    ///             PoolBalanceOpKind has three kinds
    /// Withdrawal - decrease the Pool's cash, but increase its managed balance,
    ///              leaving the total balance unchanged.
    /// Deposit - increase the Pool's cash, but decrease its managed balance,
    ///           leaving the total balance unchanged.
    /// Update - don't affect the Pool's cash balance, but change the managed balance,
    ///          so it does alter the total. The external amount can be either
    ///          increased or decreased by this call (i.e., reporting a gain or a loss).
    function _updatePoolBalance(
        IERC20 token,
        uint256 amount,
        IBVault.PoolBalanceOpKind kind
    ) internal {
        IBVault.PoolBalanceOp[] memory ops = new IBVault.PoolBalanceOp[](1);

        ops[0].kind = kind;
        ops[0].poolId = poolId;
        ops[0].token = token;
        ops[0].amount = amount;

        bVault.managePoolBalance(ops);
    }

    /// @notice Get IERC20 Tokens of Balancer Pool.
    /// @return poolTokens IERC20 tokens of Balancer Pool.
    function _getPoolTokens()
        internal
        view
        returns (IERC20[] memory poolTokens)
    {
        IERC20[] memory tokens;
        (tokens, , ) = bVault.getPoolTokens(poolId);

        // Exclude the first token(pool share).
        uint256 numPoolTokens = tokens.length - 1;
        poolTokens = new IERC20[](numPoolTokens);
        for (uint256 i = 0; i < numPoolTokens; i++) {
            poolTokens[i] = tokens[i + 1];
        }
    }

    /// @notice Get token data of Balancer Pool.
    /// @return poolTokens IERC20 tokens of Balancer Pool.
    /// @return poolHoldings Balances of tokens in Balancer Pool.
    function _getPoolTokensData()
        internal
        view
        returns (IERC20[] memory poolTokens, uint256[] memory poolHoldings)
    {
        IERC20[] memory tokens;
        uint256[] memory holdings;
        (tokens, holdings, ) = bVault.getPoolTokens(poolId);

        uint256 numPoolTokens = holdings.length - 1;
        poolTokens = new IERC20[](numPoolTokens);
        poolHoldings = new uint256[](numPoolTokens);
        for (uint256 i = 0; i < numPoolTokens; i++) {
            poolTokens[i] = tokens[i + 1];
            poolHoldings[i] = holdings[i + 1];
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
    /// @dev Will only be called by initialize() and _depositTokenToPool().
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

    /// @notice Calculate the amounts and adjustable values for rebalancing.
    /// @dev Will only be called by startRebalance().
    /// @param requests Struct details for requests.
    /// @param spotPrices Spot prices of requested assets.
    /// @param assetUnits Units in asset decimals.
    /// @return startAmounts Start amount of each assets to rebalance as requests.
    /// @return endAmounts End amount of each assets after rebalance as requests.
    /// @return adjustableAssetValue Adjustable value of assets before start rebalance.
    ///                              It's a value of assets that will not participate in the rebalancing.
    /// @return necessaryTotalValue Total value of assets that will be rebalanced.
    function _calcAmountsAndValues(
        AssetRebalanceRequest[] calldata requests,
        IAssetRegistry.AssetPriceReading[] memory spotPrices,
        uint256[] memory assetUnits
    )
        internal
        pure
        returns (
            uint256[] memory startAmounts,
            uint256[] memory endAmounts,
            uint256 adjustableAssetValue,
            uint256 necessaryTotalValue
        )
    {
        uint256 numRequests = requests.length;

        uint256[] memory values = new uint256[](numRequests);
        uint256 totalValue = 0;

        for (uint256 i = 0; i < numRequests; i++) {
            values[i] =
                (requests[i].amount * spotPrices[i].spotPrice) /
                assetUnits[i];
            totalValue += values[i];
        }

        startAmounts = new uint256[](numRequests);
        endAmounts = new uint256[](numRequests);
        uint256 adjustableCount;
        uint256 minAssetValue = type(uint256).max;

        {
            uint256 targetValue;
            for (uint256 i = 0; i < numRequests; i++) {
                targetValue = (totalValue * requests[i].weight) / _ONE;
                if (values[i] != targetValue) {
                    startAmounts[i] = requests[i].amount;
                    endAmounts[i] =
                        (targetValue * assetUnits[i]) /
                        spotPrices[i].spotPrice;

                    necessaryTotalValue += targetValue;
                    adjustableCount++;

                    if (values[i] < minAssetValue) {
                        minAssetValue = values[i];
                    }

                    if (targetValue < minAssetValue) {
                        minAssetValue = targetValue;
                    }
                }
            }
        }

        uint256 minValue = (necessaryTotalValue * _MIN_WEIGHT) / _ONE;

        if (minAssetValue > minValue) {
            adjustableAssetValue =
                (((minAssetValue - minValue)) * _ONE) /
                (_ONE - _MIN_WEIGHT * adjustableCount);
            necessaryTotalValue -= adjustableAssetValue * adjustableCount;
        } else if (minAssetValue < minValue) {
            revert Aera__WeightIsBelowMin(
                (minAssetValue * _ONE) / necessaryTotalValue,
                _MIN_WEIGHT
            );
        }
    }

    /// @notice Get valid data for rebalancing.
    /// @dev Will only be called by startRebalance().
    /// @param requests Struct details for requests.
    /// @param startAmounts Start amount of each assets to rebalance as requests.
    /// @param startWeights Start weights of each assets.
    /// @param endWeights End weights of each assets.
    /// @return rebalancingAssets Assets that will participate in rebalancing.
    /// @return validStartAmounts Amount of assets that will participate.
    /// @return validStartWeights Start weights of assets that will participate.
    /// @return validEndWeights End weights of assets that will participate.
    function _getValidRebalanceData(
        AssetRebalanceRequest[] calldata requests,
        uint256[] memory startAmounts,
        uint256[] memory startWeights,
        uint256[] memory endWeights
    )
        internal
        pure
        returns (
            IERC20[] memory rebalancingAssets,
            uint256[] memory validStartAmounts,
            uint256[] memory validStartWeights,
            uint256[] memory validEndWeights
        )
    {
        uint256 numRequests = requests.length;
        uint256 numValidAssets;
        uint256 startWeightSum;
        uint256 endWeightSum;
        for (uint256 i = 0; i < numRequests; i++) {
            if (startAmounts[i] > 0) {
                numValidAssets++;
            }
            startWeightSum += startWeights[i];
            endWeightSum += endWeights[i];
        }

        rebalancingAssets = new IERC20[](numValidAssets);
        validStartAmounts = new uint256[](numValidAssets);
        validStartWeights = new uint256[](numValidAssets);
        validEndWeights = new uint256[](numValidAssets);

        uint256 index;
        for (uint256 i = 0; i < numRequests; i++) {
            if (startAmounts[i] == 0) {
                continue;
            }

            rebalancingAssets[index] = requests[i].asset;
            validStartAmounts[index] = startAmounts[i];
            validStartWeights[index] = startWeights[i];
            validEndWeights[index] = endWeights[i];

            index++;
        }

        if (startWeightSum != _ONE) {
            validStartWeights = _normalizeWeights(
                validStartWeights,
                startWeightSum
            );
        }

        if (endWeightSum != _ONE) {
            validEndWeights = _normalizeWeights(validEndWeights, endWeightSum);
        }
    }

    /// @notice Normalize weights to make a sum of weights one.
    /// @dev Will only be called by _getValidRebalanceData().
    /// @param weights Array of weights to be normalized.
    /// @param weightSum Sum of weights.
    /// @return newWeights Array of normalized weights.
    function _normalizeWeights(
        uint256[] memory weights,
        uint256 weightSum
    ) internal pure returns (uint256[] memory newWeights) {
        uint256 numWeights = weights.length;
        newWeights = new uint256[](numWeights);

        for (uint256 i = 0; i < numWeights; i++) {
            newWeights[i] = weights[i];
        }

        if (weightSum > _ONE) {
            uint256 deviation = weightSum - _ONE;
            uint256 reducibleMinWeight = _MIN_WEIGHT + deviation;
            for (uint256 i = 0; i < numWeights; i++) {
                if (weights[i] > reducibleMinWeight) {
                    newWeights[i] -= deviation;
                    break;
                }
            }
        } else {
            newWeights[0] = newWeights[0] + _ONE - weightSum;
        }
    }

    /// @notice Adjust a Balancer pool so that the pool has only assets to be rebalanced.
    /// @dev Will only be called by startRebalance().
    /// @param rebalancingAssets Assets to rebalance.
    /// @param startAmounts Adjusted start amount of each assets to rebalance.
    ///                     It rebalances the minimal necessary amounts of assets.
    function _adjustPool(
        IERC20[] memory rebalancingAssets,
        uint256[] memory startAmounts
    ) internal {
        uint256 numAssets = rebalancingAssets.length;

        (
            IERC20[] memory poolTokens,
            uint256[] memory poolHoldings
        ) = _getPoolTokensData();

        uint256 numPoolTokens = poolTokens.length;

        _resetPoolWeights(poolTokens, numPoolTokens);

        bool isRegistered;
        uint256 index;
        uint256 startAmount;
        IERC20 asset;
        for (uint256 i = 0; i < numAssets; i++) {
            startAmount = startAmounts[i];

            asset = rebalancingAssets[i];

            (isRegistered, index) = _isAssetRegisteredToPool(
                asset,
                poolTokens,
                numPoolTokens
            );

            if (isRegistered) {
                _adjustAssetAmountInPoolToNewRequest(
                    asset,
                    startAmount,
                    poolHoldings[index]
                );
            } else {
                asset.safeTransferFrom(vault, address(this), startAmount);

                _bindAndDepositToken(asset, startAmount);
            }
        }

        (poolTokens, poolHoldings) = _getPoolTokensData();
        numPoolTokens = poolTokens.length;

        for (uint256 i = 0; i < numPoolTokens; i++) {
            if (
                !_isTokenNecessary(poolTokens[i], rebalancingAssets, numAssets)
            ) {
                _unbindAndWithdrawToken(poolTokens[i], poolHoldings[i]);
            }
        }
    }

    /// @notice Reset weights of pool tokens.
    /// @dev Will only be called by _adjustPool().
    ///      It resets weights to avoid MIN_WEIGHT error while binding.
    /// @param poolTokens IERC20 tokens of Balancer Pool.
    /// @param numPoolTokens Number of pool tokens.
    function _resetPoolWeights(
        IERC20[] memory poolTokens,
        uint256 numPoolTokens
    ) internal {
        uint256[] memory avgWeights = new uint256[](numPoolTokens);
        uint256 avgWeightSum;

        for (uint256 i = 0; i < numPoolTokens; i++) {
            avgWeights[i] = _ONE / numPoolTokens;
            avgWeightSum += avgWeights[i];
        }
        avgWeights[0] = avgWeights[0] + _ONE - avgWeightSum;

        pool.updateWeightsGradually(
            block.timestamp,
            block.timestamp,
            poolTokens,
            avgWeights
        );
    }

    /// @notice Check whether asset is registered to Balancer pool or not.
    /// @dev Will only be called by _adjustPool().
    /// @param asset Asset to check.
    /// @param poolTokens IERC20 tokens of Balancer Pool.
    /// @param numPoolTokens Number of pool tokens.
    /// @return isRegistered True if asset is registered.
    /// @return index Index of asset in Balancer pool.
    function _isAssetRegisteredToPool(
        IERC20 asset,
        IERC20[] memory poolTokens,
        uint256 numPoolTokens
    ) internal pure returns (bool isRegistered, uint256 index) {
        for (uint256 i = 0; i < numPoolTokens; i++) {
            if (asset == poolTokens[i]) {
                isRegistered = true;
                index = i;
                break;
            }
        }
    }

    /// @notice Check whether asset is necessary in Balancer pool or not.
    /// @dev Will only be called by _adjustPool().
    /// @param poolToken IERC20 token to check.
    /// @param rebalancingAssets Assets to rebalance.
    /// @param numAssets Number of assets.
    /// @return isNecessary True if asset is necessary.
    function _isTokenNecessary(
        IERC20 poolToken,
        IERC20[] memory rebalancingAssets,
        uint256 numAssets
    ) internal pure returns (bool isNecessary) {
        for (uint256 i = 0; i < numAssets; i++) {
            if (poolToken == rebalancingAssets[i]) {
                isNecessary = true;
                break;
            }
        }
    }

    /// @notice Adjust asset amounts in Balancer pool.
    /// @dev Will only be called by _adjustPool().
    /// @param asset Asset to adjust.
    /// @param startAmount Start amount of asset to rebalance.
    /// @param poolHolding Balance of asset in Balancer Pool.
    function _adjustAssetAmountInPoolToNewRequest(
        IERC20 asset,
        uint256 startAmount,
        uint256 poolHolding
    ) internal {
        if (startAmount > poolHolding) {
            asset.safeTransferFrom(
                vault,
                address(this),
                startAmount - poolHolding
            );
            _depositTokenToPool(asset, startAmount - poolHolding);
        } else if (startAmount < poolHolding) {
            _withdrawTokenFromPool(asset, poolHolding - startAmount);
        }
    }
}
