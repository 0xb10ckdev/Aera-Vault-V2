// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./dependencies/openzeppelin/Math.sol";
import "./dependencies/openzeppelin/Ownable.sol";
import "./dependencies/openzeppelin/SafeERC20.sol";
import "./interfaces/IBManagedPool.sol";
import "./interfaces/IBManagedPoolFactory.sol";
import "./interfaces/IBVault.sol";
import "./interfaces/IExecution.sol";

/// @title Aera Balancer Execution.
contract AeraBalancerExecution is IExecution, Ownable {
    using SafeERC20 for IERC20;

    uint256 internal constant _ONE = 10**18;

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

    /// @notice vault contract that the execution layer is linked to.
    address public vault;

    /// @notice Indicates that the Execution module has been initialized.
    bool public initialized;

    /// EVENTS ///

    /// ERRORS ///

    error Aera__AssetRegistryIsZeroAddress();
    error Aera__DescriptionIsEmpty();
    error Aera__ModuleIsAlreadyInitialized();
    error Aera__VaultIsZeroAddress();
    error Aera__CallerIsNotVault();
    error Aera__ModuleIsNotInitialized();
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

    /// @dev Throws if called before the module is initialized.
    modifier whenInitialized() {
        if (!initialized) {
            revert Aera__ModuleIsNotInitialized();
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

    /// @inheritdoc IExecution
    function initialize(address _vault) external override onlyOwner {
        if (initialized) {
            revert Aera__ModuleIsAlreadyInitialized();
        }

        if (_vault == address(0)) {
            revert Aera__VaultIsZeroAddress();
        }

        initialized = true;
        vault = _vault;
    }

    /// @inheritdoc IExecution
    function claimAndRebalanceGradually(
        AssetRebalanceRequest[] calldata requests,
        uint256 startTime,
        uint256 endTime
    ) external override onlyVault {
        _checkWeights(requests, startTime, endTime);

        IAssetRegistry.AssetPriceReading[] memory spotPrices = assetRegistry
            .spotPrices();

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

            values[i] = (requests[i].amount * spotPrices[i].spotPrice) / _ONE;
            totalValue += values[i];
        }

        uint256[] memory startAmounts = new uint256[](numRequests);
        uint256[] memory endAmounts = new uint256[](numRequests);
        uint256 adjustableCount;
        uint256 necessaryTotalValue;
        uint256 minAssetValue = type(uint256).max;

        uint256 targetValue;
        for (uint256 i = 0; i < numRequests; i++) {
            targetValue = (totalValue * requests[i].weight) / _ONE;
            if (values[i] != targetValue) {
                startAmounts[i] = requests[i].amount;
                endAmounts[i] =
                    (totalValue * requests[i].weight) /
                    spotPrices[i].spotPrice;

                necessaryTotalValue += targetValue;
                adjustableCount++;

                if (values[i] < targetValue) {
                    targetValue = values[i];
                }

                if (targetValue < minAssetValue) {
                    minAssetValue = targetValue;
                }
            }
        }

        uint256 minValue = (necessaryTotalValue * _MIN_WEIGHT) / _ONE;

        uint256 adjustableAssetValue;
        if (minAssetValue > minValue) {
            adjustableAssetValue =
                (adjustableCount * (minAssetValue - minValue)) /
                (_ONE - _MIN_WEIGHT * adjustableCount);
        }

        uint256[] memory startWeights = new uint256[](numRequests);
        uint256[] memory endWeights = new uint256[](numRequests);

        necessaryTotalValue -= adjustableAssetValue * adjustableCount;

        uint256 adjustableAmount;
        for (uint256 i = 0; i < numRequests; i++) {
            adjustableAmount =
                (adjustableAssetValue * _ONE) /
                spotPrices[i].spotPrice;
            if (startAmounts[i] != 0) {
                startAmounts[i] -= adjustableAmount;
                startWeights[i] =
                    (startAmounts[i] * _ONE) /
                    necessaryTotalValue;
            }
            if (endAmounts[i] != 0) {
                endAmounts[i] -= adjustableAmount;
                endWeights[i] = (endAmounts[i] * _ONE) / necessaryTotalValue;
            }
        }

        IERC20[] memory poolTokens = _getPoolTokens();
        uint256[] memory poolHoldings = _getPoolHoldings();

        uint256 numPoolTokens = poolTokens.length;
        bool isNecessaryToken;
        for (uint256 i = 0; i < numPoolTokens; i++) {
            isNecessaryToken = false;
            for (uint256 j = 0; j < numRequests; j++) {
                if (poolTokens[i] == requests[j].asset) {
                    isNecessaryToken = true;

                    if (startAmounts[j] > poolHoldings[i]) {
                        _depositTokenToPool(
                            poolTokens[i],
                            startAmounts[j] - poolHoldings[i]
                        );
                    } else if (poolHoldings[i] > startAmounts[j]) {
                        _withdrawTokenFromPool(
                            poolTokens[i],
                            poolHoldings[i] - startAmounts[j]
                        );
                    }

                    break;
                }
            }

            if (isNecessaryToken) {
                continue;
            }

            _unbindAndWithdrawToken(poolTokens[i], poolHoldings[i]);
        }

        poolTokens = _getPoolTokens();
        poolHoldings = _getPoolHoldings();
        numPoolTokens = poolTokens.length;
        bool isRegistered;
        for (uint256 i = 0; i < numRequests; i++) {
            isRegistered = false;
            if (startAmounts[i] != 0) {
                for (uint256 j = 0; j < numPoolTokens; j++) {
                    if (requests[i].asset == poolTokens[j]) {
                        isRegistered = true;
                        break;
                    }
                }
            }

            if (isRegistered) {
                continue;
            }

            _bindAndDepositToken(
                requests[i].asset,
                startAmounts[i],
                startWeights[i]
            );
        }

        poolTokens = _getPoolTokens();

        pool.updateWeightsGradually(
            block.timestamp,
            block.timestamp,
            poolTokens,
            startWeights
        );

        pool.updateWeightsGradually(startTime, endTime, poolTokens, endWeights);
    }

    /// @inheritdoc IExecution
    function claimNow() external override onlyVault {}

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
    }

    /// @inheritdoc IExecution
    function assets() public view override returns (IERC20[] memory assets) {
        (assets, , ) = bVault.getPoolTokens(poolId);
    }

    /// INTERNAL FUNCTIONS ///

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

    function _bindAndDepositToken(
        IERC20 token,
        uint256 amount,
        uint256 weight
    ) internal {
        pool.addToken(token, address(this), weight, 0, address(this));

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
}
