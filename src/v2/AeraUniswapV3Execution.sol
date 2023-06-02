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
    // TODO: this ignore yield assets
    function startRebalance(
        AssetRebalanceRequest[] calldata requests,
        uint256 startTime,
        uint256 endTime
    ) external override nonReentrant onlyVault {
        if (rebalanceEndTime > 0) {
            revert Aera__RebalancingIsOnGoing(rebalanceEndTime);
        }

        _validateRequests(requests, startTime, endTime);

        mapping(address => bool)
            memory completedOutputs = new mapping(address => bool)();
        mapping(address => bool)
            memory completedInputs = new mapping(address => bool)();
        TradePair[] memory stage1 = new TradePair[](0);
        TradePair[] memory stage2 = new TradePair[](0);
        mapping(address => uint256)
            memory currentWeights = _getCurrentWeights();
        for (uint i = 0; i < requests.length; i++) {
            // TODO: what do we do with ERC4626 assets?
            if (_isERC4626(requests[i].asset)) {
                continue;
            }
            uint256 currentWeight = currentWeights[address(requests[i].asset)];
            [
                poolPrefInPair,
                poolPrefOutPair,
                inRemainderPair,
                outRemainderPair
            ] = _getPoolPreferencesSwapPair(requests[i].asset, i, currentWeights, spotPrices);
            if (poolPrefInPair || poolPrefOutPair) {
                if (inRemainder) {
                    stage1.push(inRemainderPair);
                }
                if (outRemainderPair) {
                    stage2.push(outRemainderPair);
                }
                if (poolPrefInPair) {
                    stage1.push(poolPrefInPair);
                    completedInputs[poolPrefInPair.assetIn] = true;
                    completedOutputs[poolPrefInPair.assetOut] = true;
                } else {
                    stage2.push(poolPrefOutPair);
                    completedInputs[poolPrefOutPair.assetIn] = true;
                    completedOutputs[poolPrefOutPair.assetOut] = true;
                }
            } else if (currentWeight > requests[i].weight) {
                // if current weight is greater than requested weight, we need to sell
                if (!completedInputs[requests[i].asset]) {
                    stage1.push(
                        TradePair({
                            input: requests[i].asset,
                            output: vehicle,
                            amount: _getAmountToTradeInWETH(currentWeight, request.weight, totalNotionalVaultValue, spotPrice),
                            pool: _getPool(requests[i].asset, vehicle)
                        })
                    );
                    completedInputs[requests[i].asset] = true;
                }
            } else {
                // else buy
                if (!completedOutputs[requests[i].asset]) {
                    stage2.push(
                        TradePair({
                            input: vehicle,
                            output: requests[i].asset,
                            amount: _getAmountToTrade(currentWeight, request.weight, totalNotionalVaultValue, spotPrice),
                            pool: _getPool(vehicle, requests[i].asset)
                        })
                    );
                    completedOutputs[requests[i].asset] = true;
                }
            }
        }

        for (uint256 i = 0; i < stage1.length; i++) {
            _executeTrade(stage1[i]);
        }
        for (uint256 i = 0; i < stage2.length - 1; i++) {
            _executeTrade(stage2[i]);
        }
        // TODO: this assumes WETH is in requests
        // decide if there is extra ETH and not enough of the last asset. Basically does it make sense to swap the rest of the ETH into the last asset to be closer to the final percent, or leave it as ETH
        // TODO can save gas by checking for weth asset index above
        uint256 desiredWETHAmt = requests[_getWethAssetIndex()].weight * totalNotionalVaultValue / spotPrices[_getWethAssetIndex()];
        uint256 wethBalance = weth.getBalance(address(this));
        uint256 lastIndex = requests.length - 1;
        IERC20 lastAsset = requests[lastIndex];
        if (wethBalance > desiredWETHAmt) {
            uint256 extraWETH = wethBalance - desiredWETHAmt;
            uint256 percentExtraWETH = ONE * extraWETH / desiredWETHAmt;
            uint256 desiredAmountOfLastAsset = stage2[lastIndex];
            uint256 extraWETHInAssetTerms = extraWETH * spotPrices[lastIndex] / ONE;
            uint256 percentExtraWETHInAssetTerms = ONE * extraWETHInAssetTerms / desiredAmountOfLastAsset; 
            stage2[lastIndex].amount += extraWETHInAssetTerms;
            if (percentExtraWETHInAssetTerms < percentExtraWETH) {
                // trade the extra WETH for the last asset because the percentage off from desired is less
                // than keeping it as WETH
                desiredAmountOfLastAsset += extraWETHInAssetTerms;
                _executeTrade(stage2[lastIndex]);
            }
        } else {
            // TODO: we could also subtract from the amount we trade if that gets us closer to target weights for both weth and last asset 
        }
        _claim(requests);

        emit StartRebalance(requests, startTime, endTime);
    }

    function _getCurrentWeights()
        internal
        returns (mapping(address => uint256) weights)
    {
        AssetValue[] memory _holdings = vault.getHoldings();
        AssetPriceReading[] spotPrices = assetRegistry.spotPrices();
        AssetInformation[] assets = assetRegistry.assets();
        weights = new mapping(address => uint256)();
        uint256 totalValue = 0;
        uint256[] notionalAmounts = new uint256[](_holdings.length);
        for (uint256 i = 0; i < _holdings.length; i++) {
            if (assets[i].isERC4626) {
                // TODO: what do we do with ERC4626 assets?
                continue;
            }
            notionalAmount = spotPrices[i] * _holdings[i].value;
            notionalAmounts[i] = notionalAmount;
            totalValue += notionalAmount;
        }
        for (uint256 i = 0; i < _holdings.length; i++) {
            if (assets[i].isERC4626) {
                // TODO: what do we do with ERC4626 assets?
                continue;
            }
            weights[assets[i].address] =
                (ONE * notionalAmounts[i]) /
                totalValue;
        }
    }

    function _getPoolPreferencesSwapPair(
        AssetRebalanceRequest[] requests,
        uint256 assetIndex,
        mapping(address => uint256) currentWeights,
        uint256[] spotPrices
    )
        internal
        returns (
            TradePair poolPrefInPair,
            TradePair poolPrefOutPair,
            TradePair inRemainderPair,
            TradePair outRemainderPair
        )
    {
        IERC20 asset = requests[i].asset;
        uint256 desiredAssetAmount = _getAmountToTrade(currentWeights[address(asset)], requests[assetIndex].weight, totalNotionalVaultValue, spotPrices[assetIndex]);
        // TODO: amount units are wrong throughout this function. Should be in terms of output asset
        for (uint i = 0; i < requests.length; i++) {
            if (i == assetIndex) {
                continue
            }
            [bool isPoolPref, bool reversed] = _isPoolPref(asset, requests[i].asset);
            // TODO: can consolidate some of these that are the same in both cases
            // TODO: combine _isPoolPref with _getPoolPref
            if (isPoolPref && !reversed) {
                PoolPreference poolPref = _getPoolPref(
                    asset,
                    requests[i].asset
                );
                uint256 desiredOtherAssetAmount = _getAmountToTrade(
                    currentWeights[address(asset)],
                    requests[i].weight,
                    totalNotionalVaultValue,
                    spotPrices[i]
                );
                uint256 desiredNotionalOtherAssetAmount = _getNotional(
                    desiredOtherAssetAmount,
                    asset
                );
                if (desiredAssetAmount > desiredNotionalOtherAssetAmount) {
                    inRemainderPair = TradePair({
                        input: asset,
                        output: vehicle,
                        amount: desiredAssetAmount -
                            desiredNotionalOtherAssetAmount,
                        pool: poolPref.pool
                    });
                    poolPrefInPair = TradePair({
                        input: asset,
                        output: requests[i].asset,
                        amount: desiredNotionalOtherAssetAmount,
                        pool: poolPref.pool
                    });
                } else {
                    outRemainderPair = TradePair({
                        input: vehicle,
                        output: asset,
                        amount: desiredNotionalOtherAssetAmount -
                            desiredAssetAmount,
                        pool: poolPref.pool
                    });
                    poolPrefInPair = TradePair({
                        input: asset,
                        output: requests[i].asset,
                        amount: desiredAssetAmount,
                        pool: poolPref.pool
                    });
                }
            } else if (isPoolPref) {
                uint256 desiredOtherAssetAmount = _getAmountToTrade(
                    currentWeights[address(requests[i].asset)],
                    requests[i].weight,
                    totalNotionalVaultValue,
                    spotPrices[i]
                );
                uint256 desiredNotionalOtherAssetAmount = _getNotional(
                    desiredOtherAssetAmount,
                    asset
                );
                if (desiredAssetAmount > desiredNotionalOtherAssetAmount) {
                    outRemainderPair = TradePair({
                        input: vehicle,
                        output: asset,
                        amount: desiredAssetAmount -
                            desiredNotionalOtherAssetAmount,
                        pool: poolPref.pool
                    });
                    poolPrefInPair = TradePair({
                        input: requests[i].asset,
                        output: asset,
                        amount: desiredNotionalOtherAssetAmount,
                        pool: poolPref.pool
                    });
                } else {
                    inRemainderPair = TradePair({
                        input: asset,
                        output: vehicle,
                        amount: desiredNotionalOtherAssetAmount -
                            desiredAssetAmount,
                        pool: poolPref.pool
                    });
                    poolPrefOutPair = TradePair({
                        input: requests[i].asset,
                        output: asset,
                        amount: desiredAssetAmount,
                        pool: poolPref.pool
                    });
                }
            }
        }
    }
    
    function _isPoolPref(asset1, asset2) internal returns (boolean isPoolPref, boolean reversed) {
        for (uint256 i = 0; i < poolPreferences.length; i++) {
            if (poolPreferences[i].asset0 == asset0 &&
                    poolPreferences[i].asset1 == asset1) {
                return (true, false);
            } else if (poolPreferences[i].asset1 == asset1 &&
                    poolPreferences[i].asset0 == asset0) {
                return (true, true);
            }
        }
        return (false, false);
    }

    function _getPoolPref(
        address asset0,
        address asset1
    ) internal returns (PoolPreference poolPref) {
        for (uint256 i = 0; i < poolPreferences.length; i++) {
            if (poolPreferences[i].asset0 == asset0 &&
                    poolPreferences[i].asset1 == asset1) {
                return poolPreferences[i];
            }
        }
    }

    // amount to trade (TODO: change name)
    function _getAmountToTrade(
        uint256 currentWeight,
        uint256 targetWeight,
        uint256 totalNotionalVaultValue,
        uint256 spotPrice
    ) internal returns (uint256 amount) {
        if (targetWeight > currentWeight) {
            return
                targetWeight -
                (currentWeight * totalNotionalVaultValue) /
                ONE /
                spotPrice;
        } else {
            return
                currentWeight -
                (targetWeight * totalNotionalVaultValue) /
                ONE /
                spotPrice;
        }
    }

    function _getNotional(
        uint256 nativeAmount,
        address otherAsset
    ) internal returns (uint256 notional) {
        // notional = spotPrice(otherAsset) * nativeAmount
    }

    function _executeTrade(TradePair trade) internal {
        if (trade.inputToken.getBalance(address(this)) == 0) {
            asset.safeTransferFrom(vault, address(this), trade.amountIn);
        }
        _setAllowance(trade.tokens[0], address(trade.pool), trade.amountIn);
        trade.pool.swapExactTokensForTokens(
            trade.inputToken,
            trade.outputToken,
            trade.minAmountOut
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
