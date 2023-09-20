// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {console} from "forge-std/console.sol";
import {WstETHOracle} from "periphery/WstETHOracle.sol";
import {Test} from "forge-std/Test.sol";

contract TestWstETHOracle is Test {
    address wstETHMainnet = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    WstETHOracle oracle;

    modifier whenValidNetwork() {
        if (block.chainid != 1) {
            return;
        }
        _;
    }

    function setUp() public virtual whenValidNetwork {
        vm.roll(18130619);
        oracle = new WstETHOracle(wstETHMainnet);
    }

    function test_getDecimals() public whenValidNetwork {
        assertEq(oracle.decimals(), 18);
    }
    function test_getLatestRoundData() public whenValidNetwork {
        (
            uint80 roundId, 
            int256 answer, 
            uint256 startedAt, 
            uint256 updatedAt, 
            uint80 answeredInRound
        ) = oracle.latestRoundData();
        assertEq(roundId, 0);
        assertEq(answer, 1139685405834714356);
        assertEq(startedAt, 0);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, 0);
    }
}
