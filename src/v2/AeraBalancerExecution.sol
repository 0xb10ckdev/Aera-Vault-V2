// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./dependencies/openzeppelin/IERC20Metadata.sol";
import "./dependencies/openzeppelin/Math.sol";
import "./dependencies/openzeppelin/Ownable.sol";
import "./dependencies/openzeppelin/SafeERC20.sol";
import "./interfaces/IBalancerExecution.sol";
import "./interfaces/IBManagedPool.sol";
import "./interfaces/IBManagedPoolFactory.sol";
import "./interfaces/IBVault.sol";

/// @title Aera Balancer Execution.
contract AeraBalancerExecution is IBalancerExecution, Ownable {
    using SafeERC20 for IERC20;

    uint256 internal constant _ONE = 10 ** 18;

    /// @notice Mininum weight of pool tokens in Balancer Pool.
    uint256 private constant _MIN_WEIGHT = 0.01e18;

    /// @notice The address of asset registry.
    IAssetRegistry public immutable assetRegistry;

    /// @notice Balancer Vault.
    IBVault public immutable bVault;

    /// @notice Balancer Managed Pool.
    IBManagedPool public immutable pool;

    /// @notice Pool ID of Balancer Pool on Vault.
    bytes32 public immutable poolId;

    /// STORAGE ///

    /// @notice Describes vault purpose and modeling assumptions for differentiating between vaults.
    /// @dev string cannot be immutable bytecode but only set in constructor.
    // slither-disable-next-line immutable-states
    string public description;

    /// @notice Vault contract that the execution layer is linked to.
    address public vault;

    /// @notice Timestamp at when rebalancing ends.
    uint256 public epochEndTime;

    /// EVENTS ///

    /// @notice Emitted when module is initialized.
    /// @param vault Address of vault contract.
    event Initialize(address vault);

    /// @notice Emitted when rebalancing is started.
    /// @param requests Struct details for requests.
    /// @param startTime Timestamp at which weight movement should start.
    /// @param endTime Timestamp at which the weights should reach target values.
    event StartRebalance(
        AssetRebalanceRequest[] requests,
        uint256 startTime,
        uint256 endTime
    );

    /// @notice Emitted when endRebalance is called.
    event EndRebalance();

    /// @notice Emitted when claimNow is called.
    event ClaimNow();

    /// @notice Emitted when sweep is called.
    /// @param asset Address of an asset.
    event Sweep(IERC20 asset);

    /// ERRORS ///

    error Aera__AssetRegistryIsZeroAddress();
    error Aera__DescriptionIsEmpty();
    error Aera__ModuleIsAlreadyInitialized();
    error Aera__VaultIsZeroAddress();
    error Aera__CallerIsNotVault();
    error Aera__RebalancingIsOnGoing(uint256 endTime);
    error Aera__SumOfWeightIsNotOne();
    error Aera__WeightChangeEndBeforeStart();
    error Aera__DifferentTokensInPosition(
        address actual,
        address sortedToken,
        uint256 index
    );
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
    constructor(NewVaultParams memory vaultParams) {
        if (vaultParams.assetRegistry == address(0)) {
            revert Aera__AssetRegistryIsZeroAddress();
        }

        if (bytes(vaultParams.description).length == 0) {
            revert Aera__DescriptionIsEmpty();
        }

        uint256 numPoolTokens = vaultParams.poolTokens.length;

        address[] memory assetManagers = new address[](numPoolTokens);
        for (uint256 i = 0; i < numPoolTokens; i++) {
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
    }

    /// @inheritdoc IBalancerExecution
    function initialize(address vault_) external override onlyOwner {
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
    ) external override onlyVault {
        if (epochEndTime > 0) {
            revert Aera__RebalancingIsOnGoing(epochEndTime);
        }

        _checkWeights(requests, startTime, endTime);

        IAssetRegistry.AssetPriceReading[] memory spotPrices = assetRegistry
            .spotPrices();

        (
            uint256[] memory startAmounts,
            uint256[] memory endAmounts,
            uint256 adjustableAssetValue,
            uint256 adjustedTotalValue
        ) = _calcAmountsAndValues(requests, spotPrices);

        uint256 numRequests = requests.length;

        uint256[] memory startWeights = new uint256[](numRequests);
        uint256[] memory endWeights = new uint256[](numRequests);

        uint256 adjustableAmount;
        for (uint256 i = 0; i < numRequests; i++) {
            adjustableAmount =
                (adjustableAssetValue *
                    (10 **
                        IERC20Metadata(address(requests[i].asset))
                            .decimals())) /
                spotPrices[i].spotPrice;
            if (startAmounts[i] != 0) {
                startAmounts[i] -= adjustableAmount;
                startWeights[i] =
                    ((startAmounts[i] * spotPrices[i].spotPrice) * _ONE) /
                    (10 **
                        IERC20Metadata(address(requests[i].asset)).decimals()) /
                    adjustedTotalValue;
            }
            if (endAmounts[i] != 0) {
                endAmounts[i] -= adjustableAmount;
                endWeights[i] =
                    (endAmounts[i] * spotPrices[i].spotPrice * _ONE) /
                    (10 **
                        IERC20Metadata(address(requests[i].asset)).decimals()) /
                    adjustedTotalValue;
            }
        }

        {
            uint256 sumStartWeights;
            uint256 sumEndWeights;
            for (uint256 i = 0; i < numRequests; i++) {
                sumStartWeights += startWeights[i];
                sumEndWeights += endWeights[i];
            }

            startWeights[0] = startWeights[0] + _ONE - sumStartWeights;
            endWeights[0] = endWeights[0] + _ONE - sumEndWeights;
        }

        _adjustPool(requests, startAmounts);

        IERC20[] memory poolTokens = _getPoolTokens();

        epochEndTime = endTime;

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
    function endRebalance() external override onlyVault {
        if (block.timestamp < epochEndTime) {
            revert Aera__RebalancingIsOnGoing(epochEndTime);
        }

        _claim();

        emit EndRebalance();
    }

    /// @inheritdoc IExecution
    function claimNow() external override onlyVault {
        _claim();

        emit ClaimNow();
    }

    /// @inheritdoc IExecution
    function sweep(IERC20 token) external override onlyOwner {
        IERC20[] memory poolAssets = assets();
        uint256 numPoolAssets = poolAssets.length;

        for (uint256 i = 0; i < numPoolAssets; i++) {
            if (token == poolAssets[i]) {
                revert Aera__CannotSweepPoolAsset();
            }
        }

        uint256 amount = token.balanceOf(address(this));
        token.safeTransfer(owner(), amount);

        emit Sweep(token);
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
        IERC20[] memory poolTokens = _getPoolTokens();
        uint256[] memory poolHoldings = _getPoolHoldings();
        uint256 numPoolTokens = poolTokens.length;
        holdings = new AssetValue[](numPoolTokens);

        for (uint256 i = 0; i < numPoolTokens; i++) {
            holdings[i] = AssetValue({
                asset: poolTokens[i],
                value: poolHoldings[i]
            });
        }
    }

    /// INTERNAL FUNCTIONS ///

    function _claim() internal {
        IERC20[] memory poolTokens = _getPoolTokens();
        uint256[] memory poolHoldings = _getPoolHoldings();
        uint256 numPoolTokens = poolTokens.length;

        for (uint256 i = 0; i < numPoolTokens; i++) {
            _withdrawTokenFromPool(poolTokens[i], poolHoldings[i]);
            poolTokens[i].safeTransfer(vault, poolHoldings[i]);
        }

        epochEndTime = 0;
    }

    function _checkWeights(
        AssetRebalanceRequest[] calldata requests,
        uint256 startTime,
        uint256 endTime
    ) internal {
        uint256 numRequests = requests.length;
        uint256 weightSum = 0;
        for (uint256 i = 0; i < numRequests; i++) {
            weightSum += requests[i].weight;
        }

        if (weightSum != _ONE) {
            revert Aera__SumOfWeightIsNotOne();
        }

        startTime = Math.max(block.timestamp, startTime);
        if (startTime > endTime) {
            revert Aera__WeightChangeEndBeforeStart();
        }
    }

    function _bindAndDepositToken(IERC20 token, uint256 amount) internal {
        pool.addToken(token, address(this), _MIN_WEIGHT, 0, address(this));

        _depositTokenToPool(token, amount);
    }

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

        /// Set managed balance of token as amount
        /// i.e. Deposit amount of token to pool from Execution module
        _updatePoolBalance(token, amount, IBVault.PoolBalanceOpKind.UPDATE);
        /// Decrease managed balance and increase cash balance of the token in the pool
        /// i.e. Move amount from managed balance to cash balance
        _updatePoolBalance(token, amount, IBVault.PoolBalanceOpKind.DEPOSIT);
    }

    /// @notice Withdraw token from Balancer Pool to Execution module.
    /// @dev Will only be called by _unbindAndWithdrawTokens().
    /// @param token The token to withdraw.
    /// @param amount The amount of token to withdraw.
    function _withdrawTokenFromPool(IERC20 token, uint256 amount) internal {
        /// Decrease cash balance and increase managed balance of the pool
        /// i.e. Move amount from cash balance to managed balance
        /// and withdraw token amount from the pool to Execution module
        _updatePoolBalance(token, amount, IBVault.PoolBalanceOpKind.WITHDRAW);
        /// Adjust managed balance of the pool as the zero array
        _updatePoolBalance(token, 0, IBVault.PoolBalanceOpKind.UPDATE);
    }

    /// @dev PoolBalanceOpKind has three kinds
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

        uint256 numPoolTokens = tokens.length - 1;
        poolTokens = new IERC20[](numPoolTokens);
        for (uint256 i = 0; i < numPoolTokens; i++) {
            poolTokens[i] = tokens[i + 1];
        }
    }

    /// @notice Get balances of tokens of Balancer Pool.
    /// @return poolHoldings Balances of tokens in Balancer Pool.
    function _getPoolHoldings()
        internal
        view
        returns (uint256[] memory poolHoldings)
    {
        uint256[] memory holdings;
        (, holdings, ) = bVault.getPoolTokens(poolId);

        uint256 numPoolTokens = holdings.length - 1;
        poolHoldings = new uint256[](holdings.length - 1);
        for (uint256 i = 0; i < numPoolTokens; i++) {
            poolHoldings[i] = holdings[i + 1];
        }
    }

    /// @notice Reset allowance of token for a spender.
    /// @dev Will only be called by setAllowance() and depositUnderlyingAsset().
    /// @param token Token of address to set allowance.
    /// @param spender Address to give spend approval to.
    function _clearAllowance(IERC20 token, address spender) internal {
        // slither-disable-next-line calls-loop
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

    function _calcAmountsAndValues(
        AssetRebalanceRequest[] memory requests,
        IAssetRegistry.AssetPriceReading[] memory spotPrices
    )
        internal
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
            if (requests[i].asset != spotPrices[i].asset) {
                revert Aera__DifferentTokensInPosition(
                    address(requests[i].asset),
                    address(spotPrices[i].asset),
                    i
                );
            }

            values[i] =
                (requests[i].amount * spotPrices[i].spotPrice) /
                (10 ** IERC20Metadata(address(requests[i].asset)).decimals());
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
                        ((totalValue * requests[i].weight) *
                            (10 **
                                IERC20Metadata(address(requests[i].asset))
                                    .decimals())) /
                        _ONE /
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
        }

        necessaryTotalValue -= adjustableAssetValue * adjustableCount;
    }

    function _adjustPool(
        AssetRebalanceRequest[] calldata requests,
        uint256[] memory startAmounts
    ) internal {
        uint256 numRequests = requests.length;

        IERC20[] memory poolTokens = _getPoolTokens();
        uint256[] memory poolHoldings = _getPoolHoldings();

        uint256 numPoolTokens = poolTokens.length;

        // Reset weights to avoid MIN_WEIGHT error while binding.
        {
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

        bool isRegistered;
        for (uint256 i = 0; i < numRequests; i++) {
            if (startAmounts[i] == 0) {
                continue;
            }

            isRegistered = false;

            for (uint256 j = 0; j < numPoolTokens; j++) {
                if (requests[i].asset == poolTokens[j]) {
                    if (startAmounts[i] > poolHoldings[j]) {
                        poolTokens[j].safeTransferFrom(
                            vault,
                            address(this),
                            startAmounts[i] - poolHoldings[j]
                        );
                        _depositTokenToPool(
                            poolTokens[j],
                            startAmounts[i] - poolHoldings[j]
                        );
                    } else if (poolHoldings[j] > startAmounts[i]) {
                        _withdrawTokenFromPool(
                            poolTokens[j],
                            poolHoldings[j] - startAmounts[i]
                        );
                    }

                    isRegistered = true;
                    break;
                }
            }

            if (isRegistered) {
                continue;
            }

            requests[i].asset.safeTransferFrom(
                vault,
                address(this),
                startAmounts[i]
            );

            _bindAndDepositToken(requests[i].asset, startAmounts[i]);
        }

        poolTokens = _getPoolTokens();
        poolHoldings = _getPoolHoldings();
        numPoolTokens = poolTokens.length;

        bool isNecessaryToken;
        for (uint256 i = 0; i < numPoolTokens; i++) {
            isNecessaryToken = false;
            for (uint256 j = 0; j < numRequests; j++) {
                if (poolTokens[i] == requests[j].asset) {
                    if (startAmounts[j] > 0) {
                        isNecessaryToken = true;
                    }

                    break;
                }
            }

            if (isNecessaryToken) {
                continue;
            }

            _unbindAndWithdrawToken(poolTokens[i], poolHoldings[i]);
        }
    }
}
