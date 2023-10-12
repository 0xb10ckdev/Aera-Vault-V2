// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseWstETHOracle.sol";
import "periphery/interfaces/IWstETH.sol";

contract LatestRoundDataTest is TestBaseWstETHOracle {
    function test_latestRoundData_success_whenUnderlyingAssetsExchanged_fuzzed(
        uint256 skipTimestamp
    ) public {
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
        assertEq(
            answer, int256(IWstETH(_WSTETH_ADDRESS).getStETHByWstETH(_ONE))
        );
        assertEq(startedAt, 0);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, 0);
        assertEq(oracle.decimals(), 18);
    }
}
