// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseConstraints.sol";

contract CheckWeightsTest is TestBaseConstraints {
    uint256 internal constant _MINIMUM_WEIGHT_CHANGE_DURATION = 4 hours;
    uint256 internal constant _MAX_WEIGHT_CHANGE_RATIO = 10 ** 15;

    IConstraints.AssetWeight[] currentWeights;
    IConstraints.AssetWeight[] targetWeights;
    uint256 duration;

    function setUp() public override {
        super.setUp();

        IConstraints.AssetWeight[] memory weights = _generateValidWeights();

        for (uint256 i = 0; i < weights.length; i++) {
            currentWeights.push(weights[i]);
            targetWeights.push(weights[i]);
        }

        duration = _MINIMUM_WEIGHT_CHANGE_DURATION;
    }

    function test_checkWeights_invalid_whenDurationIsLessThanMinimum()
        public
    {
        assertFalse(
            constraints.checkWeights(
                currentWeights,
                targetWeights,
                _MINIMUM_WEIGHT_CHANGE_DURATION - 1
            )
        );
    }

    function test_checkWeights_invalid_whenNumberOfCurrentWeightsAndAssetsDoesNotMatch(
    ) public {
        currentWeights.push(currentWeights[0]);

        assertFalse(
            constraints.checkWeights(currentWeights, targetWeights, duration)
        );
    }

    function test_checkWeights_invalid_whenNumberOfTargetWeightsAndAssetsDoesNotMatch(
    ) public {
        targetWeights.pop();

        assertFalse(
            constraints.checkWeights(currentWeights, targetWeights, duration)
        );
    }

    function test_checkWeights_invalid_whenWeightChangeRatioExceedsMaximum()
        public
    {
        uint256 maximumRatio = _MAX_WEIGHT_CHANGE_RATIO * duration;
        uint256 currentWeight0 = 1e15;
        uint256 targetWeight0 = (currentWeight0 * (maximumRatio + 1)) / _ONE;
        currentWeights[1].weight += (currentWeights[0].weight - currentWeight0);
        targetWeights[1].weight -= (targetWeights[0].weight - targetWeight0);
        currentWeights[0].weight = currentWeight0;
        targetWeights[0].weight = targetWeight0;

        assertFalse(
            constraints.checkWeights(currentWeights, targetWeights, duration)
        );
    }

    function test_checkWeights_invalid_whenSumOfTargetsWeightsIsNotOne()
        public
    {
        targetWeights[0].weight += 1;

        assertFalse(
            constraints.checkWeights(currentWeights, targetWeights, duration)
        );
    }

    function test_checkWeights_valid() public {
        assertTrue(
            constraints.checkWeights(currentWeights, targetWeights, duration)
        );
    }
}