// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../TestBaseAssetRegistry.sol";

contract CheckWeightsTest is TestBaseAssetRegistry {
    uint256 internal constant MINIMUM_WEIGHT_CHANGE_DURATION = 4 hours;
    uint256 internal constant MAX_WEIGHT_CHANGE_RATIO = 10**15;

    function test_checkWeights_invalid_whenDurationIsLessThanMinimum() public {
        IAssetRegistry.AssetWeight[]
            memory currentWeights = generateValidWeights();
        IAssetRegistry.AssetWeight[]
            memory targetWeights = generateValidWeights();
        uint256 invalidDuration = MINIMUM_WEIGHT_CHANGE_DURATION - 1;

        assertFalse(
            assetRegistry.checkWeights(
                currentWeights,
                targetWeights,
                invalidDuration
            )
        );
    }

    function test_checkWeights_invalid_whenNumberOfCurrentWeightsAndAssetsDoesNotMatch()
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
        uint256 duration = MINIMUM_WEIGHT_CHANGE_DURATION;

        assertFalse(
            assetRegistry.checkWeights(invalidCurrentWeights, weights, duration)
        );
    }

    function test_checkWeights_invalid_whenNumberOfTargetWeightsAndAssetsDoesNotMatch()
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
        uint256 duration = MINIMUM_WEIGHT_CHANGE_DURATION;

        assertFalse(
            assetRegistry.checkWeights(weights, invalidTargetWeights, duration)
        );
    }

    function test_checkWeights_invalid_whenWeightChangeRatioExceedsMaximum()
        public
    {
        uint256 duration = MINIMUM_WEIGHT_CHANGE_DURATION;
        uint256 maximumRatio = MAX_WEIGHT_CHANGE_RATIO * duration;
        uint256 currentWeight0 = 1e15;
        uint256 targetWeight0 = (currentWeight0 * (maximumRatio + 1)) / ONE;
        IAssetRegistry.AssetWeight[]
            memory currentWeights = generateValidWeights();
        IAssetRegistry.AssetWeight[]
            memory targetWeights = generateValidWeights();
        currentWeights[1].weight += (currentWeights[0].weight - currentWeight0);
        targetWeights[1].weight -= (targetWeights[0].weight - targetWeight0);
        currentWeights[0].weight = currentWeight0;
        targetWeights[0].weight = targetWeight0;

        assertFalse(
            assetRegistry.checkWeights(currentWeights, targetWeights, duration)
        );
    }

    function test_checkWeights_invalid_whenSumOfTargetsWeightsIsNotOne()
        public
    {
        IAssetRegistry.AssetWeight[] memory weights = generateValidWeights();
        IAssetRegistry.AssetWeight[]
            memory invalidTargetWeights = new IAssetRegistry.AssetWeight[](
                numAssets
            );
        for (uint256 i = 0; i < numAssets; i++) {
            invalidTargetWeights[i] = weights[i];
        }
        invalidTargetWeights[0].weight += 1;
        uint256 duration = MINIMUM_WEIGHT_CHANGE_DURATION;

        assertFalse(
            assetRegistry.checkWeights(weights, invalidTargetWeights, duration)
        );
    }

    function test_checkWeights_valid() public {
        IAssetRegistry.AssetWeight[]
            memory currentWeights = generateValidWeights();
        IAssetRegistry.AssetWeight[]
            memory targetWeights = generateValidWeights();

        uint256 duration = MINIMUM_WEIGHT_CHANGE_DURATION;
        assertTrue(
            assetRegistry.checkWeights(currentWeights, targetWeights, duration)
        );
    }
}
