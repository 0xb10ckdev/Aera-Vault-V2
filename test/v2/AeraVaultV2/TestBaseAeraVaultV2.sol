// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "src/v2/AeraVaultV2.sol";
import "src/v2/interfaces/ICustodyEvents.sol";
import {TestBaseBalancer} from "test/v2/utils/TestBase/TestBaseBalancer.sol";

contract TestBaseAeraVaultV2 is TestBaseBalancer, ICustodyEvents {
    AeraVaultV2 vault;
    AssetValue[] validRequest;

    function setUp() public virtual override {
        super.setUp();

        _deployAeraVaultV2();

        for (uint256 i = 0; i < assets.length; i++) {
            assets[i].approve(
                address(vault), 1_000_000 * _getScaler(assets[i])
            );
        }

        vm.warp(block.timestamp + 1000);

        _deposit();

        _generateValidRequest();
    }

    function _deployAeraVaultV2() internal {
        vault = new AeraVaultV2(
            address(assetRegistry),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE
        );
    }

    function _generateValidRequest() internal {
        uint256[] memory weights = _normalizeWeights(_getAssetWeights());

        uint256 numERC20 = erc20Assets.length;
        uint256 index;
        for (uint256 i = 0; i < assets.length; i++) {
            if (!assetsInformation[i].isERC4626) {
                if (numERC20 % 2 == 0 || index < numERC20 - 1) {
                    uint256 adjustmentWeight = ((index / 2 + 1) * _ONE) / 100;
                    if (index % 2 == 0) {
                        weights[i] = weights[i] + adjustmentWeight;
                    } else {
                        weights[i] = weights[i] - adjustmentWeight;
                    }
                }

                index++;
            }

            validRequest.push(
                AssetValue({asset: assets[i], value: weights[i]})
            );
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
        AssetValue[] memory holdings = vault.holdings();

        uint256 totalValue;
        uint256 balance;
        uint256 index;
        for (uint256 i = 0; i < numAssets; i++) {
            if (assetsInformation[i].isERC4626) {
                balance = IERC4626(address(assetsInformation[i].asset))
                    .convertToAssets(holdings[i].value);
                index = underlyingIndex[assets[i]];
            } else {
                balance = holdings[i].value;
                index = i;
            }

            uint256 assetUnit = _getScaler(assets[index]);

            uint256 spotPrice = index == numeraire
                ? assetUnit
                : uint256(assetsInformation[index].oracle.latestAnswer());

            values[i] = (balance * spotPrice) / assetUnit;
            totalValue += values[i];
        }

        for (uint256 i = 0; i < numAssets; i++) {
            weights[i] = (values[i] * _ONE) / totalValue;
        }
    }

    function _deposit() internal {
        AssetValue[] memory amounts = new AssetValue[](assets.length);

        for (uint256 i = 0; i < assets.length; i++) {
            amounts[i] = AssetValue({
                asset: assets[i],
                value: (1_000_00e6 / oraclePrices[i]) * _getScaler(assets[i])
            });
        }

        vault.deposit(amounts);
    }

    function _normalizeWeights(uint256[] memory weights)
        internal
        pure
        returns (uint256[] memory newWeights)
    {
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
}
