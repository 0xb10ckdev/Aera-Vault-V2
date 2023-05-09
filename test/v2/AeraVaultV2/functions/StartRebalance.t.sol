// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../../utils/TestBaseCustody/functions/StartRebalance.sol";
import "../TestBaseAeraVaultV2.sol";

contract StartRebalanceTest is BaseStartRebalanceTest, TestBaseAeraVaultV2 {
    function test_startRebalance_success_whenNoYieldAssetsShouldBeAdjusted()
        public
    {
        ICustody.AssetValue[] memory requests = _generateValidRequest();

        uint256[] memory weights = _getAssetWeights();

        weights = _normalizeWeights(weights);

        uint256 index;
        for (uint256 i = 0; i < assets.length; i++) {
            if (!assetsInformation[i].isERC4626) {
                if (
                    erc20Assets.length % 2 == 0 ||
                    index < erc20Assets.length - 1
                ) {
                    if (index % 2 == 0) {
                        weights[i] =
                            weights[i] +
                            ((index / 2 + 1) * _ONE) /
                            100;
                    } else {
                        weights[i] =
                            weights[i] -
                            ((index / 2 + 1) * _ONE) /
                            100;
                    }
                }

                index++;
            }

            requests[i].value = weights[i];
        }

        uint256[] memory balances = _getAssetBalances();

        vm.startPrank(vault.guardian());

        vm.expectEmit(true, true, true, true, address(vault));
        emit StartRebalance(requests, block.timestamp, block.timestamp + 100);

        vault.startRebalance(requests, block.timestamp, block.timestamp + 100);

        vm.stopPrank();

        vm.warp(vault.execution().rebalanceEndTime());

        _swap(_getTargetAmounts());

        vault.endRebalance();

        uint256[] memory currentBalances = _getAssetBalances();
        uint256[] memory currentWeights = _getAssetWeights();

        for (uint256 i = 0; i < assets.length; i++) {
            if (assetsInformation[i].isERC4626) {
                assertApproxEqRel(balances[i], currentBalances[i], 0.001e18);
            }
            assertApproxEqAbs(weights[i], currentWeights[i], 0.05e18);
        }
    }

    function test_startRebalance_success_whenYieldActionAmountIsLessThanThreshold()
        public
    {
        ICustody.AssetValue[] memory requests = _generateValidRequest();

        uint256[] memory weights = _getAssetWeights();

        weights = _normalizeWeights(weights);

        uint256 index;
        for (uint256 i = 0; i < assets.length; i++) {
            if (!assetsInformation[i].isERC4626) {
                if (
                    erc20Assets.length % 2 == 0 ||
                    index < erc20Assets.length - 1
                ) {
                    if (index % 2 == 0) {
                        weights[i] =
                            weights[i] +
                            ((index / 2 + 1) * _ONE) /
                            100;
                    } else {
                        weights[i] =
                            weights[i] -
                            ((index / 2 + 1) * _ONE) /
                            100;
                    }
                }

                requests[i].value = weights[i];
                index++;
            }
        }

        index = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            if (assetsInformation[i].isERC4626) {
                if (
                    yieldAssets.length % 2 == 0 ||
                    index < yieldAssets.length - 1
                ) {
                    if (index % 2 == 0) {
                        weights[i] = weights[i] + 0.0001e18;
                    } else {
                        weights[i] = weights[i] - 0.0001e18;
                    }
                }

                requests[i].value = weights[i];
                index++;
            }
        }

        uint256[] memory balances = _getAssetBalances();

        vm.startPrank(vault.guardian());

        vm.expectEmit(true, true, true, true, address(vault));
        emit StartRebalance(requests, block.timestamp, block.timestamp + 100);

        vault.startRebalance(requests, block.timestamp, block.timestamp + 100);

        vm.stopPrank();

        vm.warp(vault.execution().rebalanceEndTime());

        _swap(_getTargetAmounts());

        vault.endRebalance();

        uint256[] memory currentBalances = _getAssetBalances();
        uint256[] memory currentWeights = _getAssetWeights();

        for (uint256 i = 0; i < assets.length; i++) {
            if (assetsInformation[i].isERC4626) {
                assertApproxEqRel(balances[i], currentBalances[i], 0.001e18);
            }
            assertApproxEqAbs(weights[i], currentWeights[i], 0.05e18);
        }
    }

    function test_startRebalance_success_whenYieldAssetsShouldBeAdjusted()
        public
    {
        ICustody.AssetValue[] memory requests = _generateValidRequest();

        uint256[] memory weights = _getAssetWeights();

        weights = _normalizeWeights(weights);

        for (uint256 i = 0; i < assets.length; i++) {
            if (assets.length % 2 == 0 || i < assets.length - 1) {
                if (i % 2 == 0) {
                    weights[i] = weights[i] + ((i / 2 + 1) * _ONE) / 100;
                } else {
                    weights[i] = weights[i] - ((i / 2 + 1) * _ONE) / 100;
                }
            }

            requests[i].value = weights[i];
        }

        vm.startPrank(vault.guardian());

        vm.expectEmit(true, true, true, true, address(vault));
        emit StartRebalance(requests, block.timestamp, block.timestamp + 100);

        vault.startRebalance(requests, block.timestamp, block.timestamp + 100);

        vm.stopPrank();

        vm.warp(vault.execution().rebalanceEndTime());

        _swap(_getTargetAmounts());

        vault.endRebalance();

        uint256[] memory currentWeights = _getAssetWeights();

        for (uint256 i = 0; i < assets.length; i++) {
            assertApproxEqAbs(weights[i], currentWeights[i], 0.05e18);
        }
    }

    function _getAssetBalances()
        internal
        view
        returns (uint256[] memory balances)
    {
        balances = new uint256[](assets.length);

        for (uint256 i = 0; i < assets.length; i++) {
            balances[i] = assets[i].balanceOf(address(vault));
        }
    }

    function _getAssetWeights()
        internal
        view
        returns (uint256[] memory weights)
    {
        uint256 numAssets = assets.length;
        uint256[] memory values = new uint256[](numAssets);
        weights = new uint256[](numAssets);
        ICustody.AssetValue[] memory holdings = vault.holdings();

        uint256 totalValue;
        uint256 balance;
        uint256 spotPrice;
        uint256 assetUnit;
        for (uint256 i = 0; i < numAssets; i++) {
            if (assetsInformation[i].isERC4626) {
                balance = IERC4626(address(assetsInformation[i].asset))
                    .convertToAssets(holdings[i].value);
                assetUnit = _getScaler(assets[underlyingIndex[assets[i]]]);
                if (underlyingIndex[assets[i]] == numeraire) {
                    spotPrice = assetUnit;
                } else {
                    spotPrice = uint256(
                        assetsInformation[underlyingIndex[assets[i]]]
                            .oracle
                            .latestAnswer()
                    );
                }
            } else {
                balance = holdings[i].value;
                assetUnit = _getScaler(assets[i]);
                if (i == numeraire) {
                    spotPrice = assetUnit;
                } else {
                    spotPrice = uint256(
                        assetsInformation[i].oracle.latestAnswer()
                    );
                }
            }

            values[i] = (balance * spotPrice) / assetUnit;
            totalValue += values[i];
        }

        for (uint256 i = 0; i < numAssets; i++) {
            weights[i] = (values[i] * _ONE) / totalValue;
        }
    }

    function _generateRequest()
        internal
        view
        override
        returns (ICustody.AssetValue[] memory requests)
    {
        return _generateValidRequest();
    }
}
