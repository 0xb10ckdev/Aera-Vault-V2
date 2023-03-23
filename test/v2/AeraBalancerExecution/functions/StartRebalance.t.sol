// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {IManagedPool} from "../../../../src/v2/dependencies/balancer-labs/interfaces/contracts/pool-utils/IManagedPool.sol";
import {IAsset} from "../../../../src/v2/dependencies/balancer-labs/interfaces/contracts/vault/IAsset.sol";
import {IVault} from "../../../../src/v2/dependencies/balancer-labs/interfaces/contracts/vault/IVault.sol";
import "../TestBaseBalancerExecution.sol";

contract StartRebalanceTest is TestBaseBalancerExecution {
    function test_startRebalance_fail_whenCallerIsNotOwner() public {
        vm.startPrank(_USER);

        vm.expectRevert(AeraBalancerExecution.Aera__CallerIsNotVault.selector);
        balancerExecution.startRebalance(
            _generateRequestWith2Assets(),
            block.timestamp,
            block.timestamp + 10000
        );
    }

    function test_startRebalance_fail_whenRebalancingIsOnGoing() public {
        _startRebalance(_generateRequestWith2Assets());

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraBalancerExecution.Aera__RebalancingIsOnGoing.selector,
                balancerExecution.epochEndTime()
            )
        );

        balancerExecution.startRebalance(
            _generateRequestWith2Assets(),
            block.timestamp,
            block.timestamp + 10000
        );
    }

    function test_startRebalance_fail_whenSumOfWeightIsNotOne() public {
        IExecution.AssetRebalanceRequest[]
            memory requests = _generateRequestWith2Assets();
        requests[0].weight--;

        vm.expectRevert(
            AeraBalancerExecution.Aera__SumOfWeightIsNotOne.selector
        );

        balancerExecution.startRebalance(
            requests,
            block.timestamp,
            block.timestamp + 10000
        );
    }

    function test_startRebalance_fail_whenWeightChangeEndBeforeStart() public {
        vm.expectRevert(
            AeraBalancerExecution.Aera__WeightChangeEndBeforeStart.selector
        );

        balancerExecution.startRebalance(
            _generateRequestWith2Assets(),
            block.timestamp + 100,
            block.timestamp + 10
        );
    }

    function test_startRebalance_fail_whenTokenPositionIsDifferent() public {
        IExecution.AssetRebalanceRequest[]
            memory requests = _generateRequestWith2Assets();
        IERC20 asset = requests[0].asset;
        requests[0].asset = requests[1].asset;
        requests[1].asset = asset;

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraBalancerExecution.Aera__DifferentTokensInPosition.selector,
                requests[0].asset,
                asset,
                0
            )
        );

        balancerExecution.startRebalance(
            requests,
            block.timestamp,
            block.timestamp + 10000
        );
    }

    function test_startRebalance_with_2_assets_success() public {
        _rebalanceWith2Assets();
    }

    function test_startRebalance_with_3_assets_success() public {
        _rebalanceWith3Assets();
    }

    function test_startRebalance_with_3_assets_after_2_assets_success() public {
        _rebalanceWith2Assets();
        _rebalanceWith3Assets();
    }

    function _rebalanceWith2Assets() internal {
        _rebalance(_generateRequestWith2Assets());
    }

    function _rebalanceWith3Assets() internal {
        _rebalance(_generateRequestWith3Assets());
    }

    function _generateRequestWith2Assets()
        internal
        returns (IExecution.AssetRebalanceRequest[] memory requests)
    {
        requests = new IExecution.AssetRebalanceRequest[](2);

        // WBTC
        requests[0] = IExecution.AssetRebalanceRequest({
            asset: erc20Assets[0],
            amount: 5e8,
            weight: 0.69e18
        });
        // USDC
        requests[1] = IExecution.AssetRebalanceRequest({
            asset: erc20Assets[1],
            amount: 80_000e6,
            weight: 0.31e18
        });
    }

    function _generateRequestWith3Assets()
        internal
        returns (IExecution.AssetRebalanceRequest[] memory requests)
    {
        requests = new IExecution.AssetRebalanceRequest[](3);

        // WBTC
        requests[0] = IExecution.AssetRebalanceRequest({
            asset: erc20Assets[0],
            amount: 5e8,
            weight: 0.34e18
        });
        // USDC
        requests[1] = IExecution.AssetRebalanceRequest({
            asset: erc20Assets[1],
            amount: 80_000e6,
            weight: 0.31e18
        });
        // WETH
        requests[2] = IExecution.AssetRebalanceRequest({
            asset: erc20Assets[2],
            amount: 100e18,
            weight: 0.35e18
        });
    }

    function _rebalance(
        IExecution.AssetRebalanceRequest[] memory requests
    ) internal {
        _startRebalance(requests);

        vm.warp(balancerExecution.epochEndTime());

        _swap(_getTargetAmounts());

        balancerExecution.claimNow();
    }

    function _startRebalance(
        IExecution.AssetRebalanceRequest[] memory requests
    ) internal {
        for (uint256 i = 0; i < requests.length; i++) {
            requests[i].asset.approve(
                address(balancerExecution),
                type(uint256).max
            );
        }

        uint256 startTime = block.timestamp + 10;
        uint256 endTime = startTime + 10000;

        balancerExecution.startRebalance(requests, startTime, endTime);
    }

    // Simulate swaps
    function _swap(uint256[] memory targetAmounts) internal {
        vm.startPrank(_USER);

        for (uint256 i = 0; i < erc20Assets.length; i++) {
            erc20Assets[i].approve(_BVAULT_ADDRESS, type(uint256).max);
        }

        IVault.FundManagement memory fundManagement = IVault.FundManagement({
            sender: _USER,
            fromInternalBalance: true,
            recipient: payable(_USER),
            toInternalBalance: true
        });

        IExecution.AssetValue[] memory holdings;

        for (uint256 i = 0; i < targetAmounts.length - 1; i++) {
            targetAmounts[i] = (targetAmounts[i] * (_ONE - 1e12)) / _ONE;
            while (true) {
                holdings = balancerExecution.holdings();

                if (holdings[i].value < targetAmounts[i]) {
                    uint256 necessaryAmount = targetAmounts[i] -
                        holdings[i].value;
                    IVault(_BVAULT_ADDRESS).swap(
                        IVault.SingleSwap({
                            poolId: balancerExecution.poolId(),
                            kind: IVault.SwapKind.GIVEN_IN,
                            assetIn: IAsset(address(erc20Assets[i])),
                            assetOut: IAsset(address(erc20Assets[i + 1])),
                            amount: necessaryAmount <
                                (holdings[i].value * 3) / 10
                                ? necessaryAmount
                                : (holdings[i].value * 3) / 10,
                            userData: "0x"
                        }),
                        fundManagement,
                        0,
                        block.timestamp + 100
                    );
                } else if (holdings[i].value > targetAmounts[i]) {
                    uint256 necessaryAmount = holdings[i].value -
                        targetAmounts[i];
                    IVault(_BVAULT_ADDRESS).swap(
                        IVault.SingleSwap({
                            poolId: balancerExecution.poolId(),
                            kind: IVault.SwapKind.GIVEN_OUT,
                            assetIn: IAsset(address(erc20Assets[i + 1])),
                            assetOut: IAsset(address(erc20Assets[i])),
                            amount: necessaryAmount < holdings[i].value / 4
                                ? necessaryAmount
                                : holdings[i].value / 4,
                            userData: "0x"
                        }),
                        fundManagement,
                        type(uint256).max,
                        block.timestamp + 100
                    );
                } else {
                    break;
                }
            }
        }

        vm.stopPrank();
    }

    function _getWeights() internal returns (uint256[] memory weights) {
        IAssetRegistry.AssetPriceReading[] memory spotPrices = assetRegistry
            .spotPrices();
        uint256[] memory values = new uint256[](erc20Assets.length);
        uint256 totalValue;

        for (uint256 i = 0; i < erc20Assets.length; i++) {
            for (uint256 j = 0; j < spotPrices.length; j++) {
                if (erc20Assets[i] == spotPrices[j].asset) {
                    values[i] =
                        (erc20Assets[i].balanceOf(address(this)) *
                            spotPrices[j].spotPrice) /
                        (10 **
                            IERC20Metadata(address(erc20Assets[i])).decimals());
                    totalValue += values[i];

                    break;
                }
            }
        }

        weights = new uint256[](erc20Assets.length);
        for (uint256 i = 0; i < erc20Assets.length; i++) {
            weights[i] = (values[i] * _ONE) / totalValue;
        }
    }

    function _getTargetAmounts()
        internal
        returns (uint256[] memory targetAmounts)
    {
        IERC20[] memory poolTokens = balancerExecution.assets();
        IExecution.AssetValue[] memory holdings = balancerExecution.holdings();
        IAssetRegistry.AssetPriceReading[] memory spotPrices = assetRegistry
            .spotPrices();
        uint256[] memory values = new uint256[](poolTokens.length);
        uint256 totalValue;

        for (uint256 i = 0; i < poolTokens.length; i++) {
            for (uint256 j = 0; j < spotPrices.length; j++) {
                if (poolTokens[i] == spotPrices[j].asset) {
                    values[i] =
                        (holdings[i].value * spotPrices[j].spotPrice) /
                        (10 **
                            IERC20Metadata(address(poolTokens[i])).decimals());
                    totalValue += values[i];

                    break;
                }
            }
        }

        uint256[] memory poolWeights = IManagedPool(
            address(balancerExecution.pool())
        ).getNormalizedWeights();

        targetAmounts = new uint256[](poolTokens.length);

        for (uint256 i = 0; i < poolTokens.length; i++) {
            for (uint256 j = 0; j < spotPrices.length; j++) {
                if (poolTokens[i] == spotPrices[j].asset) {
                    targetAmounts[i] =
                        ((totalValue * poolWeights[i]) *
                            (10 **
                                IERC20Metadata(address(poolTokens[i]))
                                    .decimals())) /
                        _ONE /
                        spotPrices[j].spotPrice;

                    break;
                }
            }
        }
    }
}
