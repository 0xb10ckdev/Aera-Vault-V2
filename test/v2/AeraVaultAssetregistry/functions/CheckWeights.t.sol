// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../TestBaseAssetRegistry.sol";

contract CheckWeightsTest is TestBaseAssetRegistry {
    uint256 internal constant MINIMUM_WEIGHT_CHANGE_DURATION = 4 hours;
    uint256 internal constant MAX_WEIGHT_CHANGE_RATIO = 10**15;

    IAssetRegistry.AssetWeight[] currentWeights;
    IAssetRegistry.AssetWeight[] targetWeights;
    uint256 duration;

    function setUp() public override {
        _deploy();

        IAssetRegistry.AssetWeight[] memory weights = _generateValidWeights();

        for (uint256 i = 0; i < numAssets; i++) {
            currentWeights.push(weights[i]);
            targetWeights.push(weights[i]);
        }

        duration = MINIMUM_WEIGHT_CHANGE_DURATION;
    }

    function test_checkWeights_invalid_whenDurationIsLessThanMinimum() public {
        assertFalse(
            assetRegistry.checkWeights(
                currentWeights,
                targetWeights,
                MINIMUM_WEIGHT_CHANGE_DURATION - 1
            )
        );
    }

    function test_checkWeights_invalid_whenNumberOfCurrentWeightsAndAssetsDoesNotMatch()
        public
    {
        currentWeights.push(currentWeights[0]);

        assertFalse(
            assetRegistry.checkWeights(currentWeights, targetWeights, duration)
        );
    }

    function test_checkWeights_invalid_whenNumberOfTargetWeightsAndAssetsDoesNotMatch()
        public
    {
        targetWeights.pop();

        assertFalse(
            assetRegistry.checkWeights(currentWeights, targetWeights, duration)
        );
    }

    function test_checkWeights_invalid_whenWeightChangeRatioExceedsMaximum()
        public
    {
        uint256 maximumRatio = MAX_WEIGHT_CHANGE_RATIO * duration;
        uint256 currentWeight0 = 1e15;
        uint256 targetWeight0 = (currentWeight0 * (maximumRatio + 1)) / ONE;
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
        targetWeights[0].weight += 1;

        assertFalse(
            assetRegistry.checkWeights(currentWeights, targetWeights, duration)
        );
    }

    function test_checkWeights_valid() public {
        assertTrue(
            assetRegistry.checkWeights(currentWeights, targetWeights, duration)
        );
    }
}
