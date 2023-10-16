// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseCurveOracle.sol";
import "@openzeppelin/IERC20.sol";
import "periphery/interfaces/ICurveFiPool.sol";

contract LatestRoundDataTest is TestBaseCurveOracle {
    function test_latestRoundData_success_whenNoUnderlyingAssetsExchanged_fuzzed(
        uint256 skipTimestamp
    ) public {
        (,,, uint256 prevUpdatedAt,) = oracle.latestRoundData();

        vm.assume(skipTimestamp < 1e9);
        skip(skipTimestamp);

        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = oracle.latestRoundData();

        assertEq(roundId, 0);
        assertEq(answer, int256(ICurveFiPool(_CURVE_TETH_POOL).price_oracle()));
        assertEq(startedAt, 0);
        assertEq(updatedAt, prevUpdatedAt);
        assertEq(answeredInRound, 0);
        assertEq(oracle.decimals(), 18);
    }

    function test_latestRoundData_success_whenUnderlyingAssetsExchanged_fuzzed(
        uint256 skipTimestamp
    ) public {
        vm.assume(skipTimestamp < 1e9);
        skip(skipTimestamp);

        deal(_WETH_ADDRESS, address(this), _ONE);
        IERC20(_WETH_ADDRESS).approve(_CURVE_TETH_POOL, _ONE);

        ICurveFiPool(_CURVE_TETH_POOL).exchange(0, 1, _ONE, 0.9e18);

        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = oracle.latestRoundData();

        assertEq(roundId, 0);
        assertEq(answer, int256(ICurveFiPool(_CURVE_TETH_POOL).price_oracle()));
        assertEq(startedAt, 0);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, 0);
        assertEq(oracle.decimals(), 18);
    }
}
