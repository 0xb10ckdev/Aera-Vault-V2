// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./dependencies/openzeppelin/IERC20Metadata.sol";
import "./dependencies/openzeppelin/Math.sol";
import "./dependencies/openzeppelin/Ownable.sol";
import "./dependencies/openzeppelin/ReentrancyGuard.sol";
import "./dependencies/openzeppelin/SafeERC20.sol";
import "./interfaces/IAssetRegistry.sol";
import "./interfaces/IUniswapV3Execution.sol";
import "./interfaces/IBManagedPool.sol";
import "./interfaces/IBManagedPoolFactory.sol";
import "./interfaces/IBMerkleOrchard.sol";
import "./interfaces/IBVault.sol";

/// @title Aera Uniswap V3 Execution.
contract AeraUniswapV3Execution is
    IUniswapV3Execution,
    Ownable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    uint256 internal constant _ONE = 1e18;

    /// @notice The address of asset registry.
    IAssetRegistry public immutable assetRegistry;

    IERC20 public vehicle;
    uint256 public maxSlippage;
    PoolPreference[] public poolPreferences;

    /// STORAGE ///

    /// @notice Describes execution module and which custody vault it is intended for.
    /// @dev string cannot be immutable bytecode but only set in constructor.
    string public description;

    /// @notice Vault contract that the execution layer is linked to.
    address public vault;

    /// @notice Timestamp at when rebalancing ends.
    uint256 public rebalanceEndTime;

    /// ERRORS ///

    error Aera__AssetRegistryIsZeroAddress();
    error Aera__DescriptionIsEmpty();
    error Aera__PoolPreferenceTokenIsNotRegistered(IERC20 poolPreferenceToken);
    error Aera__VehicleIsNotRegistered(IERC20 vehicle);
    error Aera__ModuleIsAlreadyInitialized();
    error Aera__VaultIsZeroAddress();
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

    /// @param executionParams Struct execution parameters.
    constructor(NewUniswapV3ExecutionParams memory executionParams) {
        if (executionParams.assetRegistry == address(0)) {
            revert Aera__AssetRegistryIsZeroAddress();
        }

        if (bytes(executionParams.description).length == 0) {
            revert Aera__DescriptionIsEmpty();
        }
        description = executionParams.description;

        assetRegistry = IAssetRegistry(executionParams.assetRegistry);

        vehicle = IERC20(executionParams.vehicle);
        if (!_assetRegistered(executionParams.vehicle)) {
            revert Aera__VehicleIsNotRegistered(vehicle);
        }

        // TODO: do we want to add a max limit to maxSlippage or does it not matter?
        maxSlippage = executionParams.maxSlippage;

        for (uint256 i = 0; i < executionParams.poolPreferences.length; i++) {
            PoolPreference memory poolPreference = executionParams
                .poolPreferences[i];
            if (!_assetRegistered(address(poolPreference.asset0))) {
                revert Aera__PoolPreferenceTokenIsNotRegistered(
                    poolPreference.asset0
                );
            }
            if (!_assetRegistered(address(poolPreference.asset1))) {
                revert Aera__PoolPreferenceTokenIsNotRegistered(
                    poolPreference.asset1
                );
            }
            poolPreferences.push(poolPreference);
        }
    }

    // TODO: can optimize gas by passing in a list of all the assets to check
    // and returning which are registered
    function _assetRegistered(address asset) internal view returns (bool) {
        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();
        for (uint256 i = 0; i < assets.length; i++) {
            if (address(assets[i].asset) == asset) {
                return true;
            }
        }
        return false;
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

        TradePair[] memory pairs = _calcInputOutputPairs(requests);
        TradeStage[] memory tradeStages = _calcTradeStages(requests);
        _executeTradeStages(tradeStages);


        _claim(requests);

        emit StartRebalance(requests, startTime, endTime);
    }

    function _calcInputOutputPairs(
        AssetRebalanceRequest[] calldata requests
    )
        internal
        returns (TradePair[] memory pairs)
    {}

    function _calcTradeStages(
        TradePair[] memory pairs
    ) internal returns (TradeStage[] memory tradeStages) {
        mapping(TradePair => bool)
            memory completed_pairs = new mapping(TradePair => bool)();
        // TODO: this needs to happen at the request/calcInputOutputPairs level
        for (uint256 i = 0; i < poolPreferences.length; i++) {
            uint256 matchingPairI = MAXINT;
            for (uint256 j = 0; j < pairs.length; j++) {
                if (poolPreferences[i].asset0 == pairs[j].input && poolPreferences[i].asset1 == pairs[j].output) {
                    matchingPairI = j;
                    break;
                }
            }
            if (matchingPairI < MAXINT) {
                // TODO: figure out which direction to swap, and only
                // add to completed assets if:
                // - all of input asset was used (for input)
                // - all of output asset was gained (for output)
                // - add leftover to "adjusted amounts"
                AssetValue minAmountOut = _calcMinAmountOut(
                    pair.input,
                    pair.output,
                    pair.amount
                );
                tradeStages.push(
                    TradeStage({input: pair.input, output: pair.output, inputAmount: pair.amount, minAmountOut: minAmountOut})
                );
                completed_pairs[pair] = true;
            }
        }
        for (uint256 j = 0; j < pairs.length; j++) {
            if (
                completed_pairs[pairs[j]] == false
            ) {
                AssetValue minAmountOut = _calcMinAmountOut(
                    pairs[j].input,
                    pairs[j].output,
                    pairs[j].amount
                );
                tradeStages.push(
                    TradeStage({
                        input: pair.input,
                        output: pair.output,
                        inputAmount: pair.amount,
                        minAmountOut: minAmountOut
                    })
                );
            }
        }
    }

    function _executeTradeStages(TradeStage[] memory tradeStages);
        for (uint256 i = 0; i < tradeStages.length; i++) {
            _executeTradeStage(tradeStages[i]);
        }
    }

    function _executeTradeStage(TradeStage tradeStage) internal {
        if (tradeStage.inputToken.getBalance(address(this)) == 0) {
            asset.safeTransferFrom(vault, address(this), tradeStage.amountIn);
        }
        _setAllowance(
            tradeStage.tokens[0],
            address(tradeStage.pool),
            tradeStage.amountIn
        );
        tradeStage.pool.swapExactTokensForTokens(
            tradeStage.inputToken,
            tradeStage.outputToken,
            tradeStage.minAmountOut
        );
    }

    /// @inheritdoc IExecution
    function endRebalance() external override nonReentrant onlyVault {
        if (rebalanceEndTime == 0) {
            revert Aera__RebalancingHasNotStarted();
        }
        if (block.timestamp < rebalanceEndTime) {
            revert Aera__RebalancingIsOnGoing(rebalanceEndTime);
        }

        // TODO

        emit EndRebalance();
    }

    /// @inheritdoc IExecution
    function claimNow() external override nonReentrant onlyVault {
        // TODO
        emit ClaimNow();
    }

    function _claim(AssetRebalanceRequest[] calldata requests) internal {
        for (uint256 i = 0; i < requests.length; i++) {
            AssetRebalanceRequest memory request = requests[i];
            if (requests.outputToken.getBalance(address(this)) > 0) {
                requests.outputToken.safeTransfer(
                    vault,
                    requests.outputToken.getBalance(address(this))
                );
            }
        }
    }

    /// @inheritdoc IExecution
    function sweep(IERC20 token) external override nonReentrant {
        uint256 amount = token.balanceOf(address(this));
        token.safeTransfer(owner(), amount);
        emit Sweep(token);
    }

    /// @inheritdoc IExecution
    function holdings() public pure override returns (AssetValue[] memory) {
        return new AssetValue[](0);
    }

    /// INTERNAL FUNCTIONS ///

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
}
