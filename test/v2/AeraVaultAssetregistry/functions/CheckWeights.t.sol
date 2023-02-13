// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../TestBaseAssetRegistry.sol";

contract CheckWeightsTest is TestBaseAssetRegistry {
    function test_checkWeights_fail_whenNumberOfCurrentWeightsAndAssetsDoesNotMatch()
        public
    {
        IAssetRegistry.AssetWeight[] memory weights = generateValidWeights();
        IAssetRegistry.AssetWeight[]
            memory invalidCurrentWeights = new IAssetRegistry.AssetWeight[](
                numAssets + 1
            );
        for (uint256 i = 0; i < numAssets; i++) {
            invalidCurrentWeights[i] = weights[i];
        }
        invalidCurrentWeights[numAssets] = weights[0];

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__ValueLengthIsNotSame.selector,
                numAssets,
                invalidCurrentWeights.length
            )
        );
        assetRegistry.checkWeights(invalidCurrentWeights, weights);
    }

    function test_checkWeights_fail_whenNumberOfTargetWeightsAndAssetsDoesNotMatch()
        public
    {
        IAssetRegistry.AssetWeight[] memory weights = generateValidWeights();
        IAssetRegistry.AssetWeight[]
            memory invalidTargetWeights = new IAssetRegistry.AssetWeight[](
                numAssets - 1
            );
        for (uint256 i = 0; i < numAssets - 1; i++) {
            invalidTargetWeights[i] = weights[i];
        }

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__ValueLengthIsNotSame.selector,
                numAssets,
                invalidTargetWeights.length
            )
        );
        assetRegistry.checkWeights(weights, invalidTargetWeights);
    }

    function test_checkWeights_fail_whenSumOfTargetsWeightsIsNotOne() public {
        IAssetRegistry.AssetWeight[] memory weights = generateValidWeights();
        IAssetRegistry.AssetWeight[]
            memory invalidTargetWeights = new IAssetRegistry.AssetWeight[](
                numAssets
            );
        for (uint256 i = 0; i < numAssets; i++) {
            invalidTargetWeights[i] = weights[i];
        }
        invalidTargetWeights[0].weight += 1;

        vm.expectRevert(
            AeraVaultAssetRegistry.Aera__SumOfWeightsIsNotOne.selector
        );
        assetRegistry.checkWeights(weights, invalidTargetWeights);
    }

    function test_checkWeights_success() public {
        IAssetRegistry.AssetWeight[]
            memory currentWeights = generateValidWeights();
        IAssetRegistry.AssetWeight[]
            memory targetWeights = generateValidWeights();

        assertTrue(assetRegistry.checkWeights(currentWeights, targetWeights));
    }
}
