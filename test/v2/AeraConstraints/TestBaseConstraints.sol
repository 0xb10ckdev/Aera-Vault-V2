// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "src/v2/interfaces/IAssetRegistry.sol";
import "src/v2/interfaces/IConstraints.sol";
import "src/v2/interfaces/IConstraintsEvents.sol";
import "src/v2/AeraVaultAssetRegistry.sol";
import {TestBaseBalancer} from "test/v2/utils/TestBase/TestBaseBalancer.sol";

contract TestBaseConstraints is TestBaseBalancer, IConstraintsEvents {
    function _generateValidWeights()
        internal
        view
        returns (IConstraints.AssetWeight[] memory weights)
    {
        IAssetRegistry.AssetInformation[] memory registryAssets =
            assetRegistry.assets();
        uint256 numAssets = registryAssets.length;
        weights = new IConstraints.AssetWeight[](numAssets);

        uint256 weightSum;
        for (uint256 i = 0; i < numAssets; i++) {
            weights[i] = IConstraints.AssetWeight({
                asset: registryAssets[i].asset,
                weight: _ONE / numAssets
            });
            weightSum += _ONE / numAssets;
        }

        weights[numAssets - 1].weight += _ONE - weightSum;
    }
}
