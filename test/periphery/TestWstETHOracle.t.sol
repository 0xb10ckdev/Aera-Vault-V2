// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {console} from "forge-std/console.sol";
import {WstETHOracle} from "periphery/WstETHOracle.sol";
import {Test} from "forge-std/Test.sol";
import {ONE} from "src/v2/Constants.sol";

contract MockWstETH {
    uint256 exchangeRate;

    constructor(uint256 exchangeRate_) {
        exchangeRate = exchangeRate_;
    }

    function getStETHByWstETH(uint256 _wstETHAmount)
        external
        view
        returns (uint256)
    {
        return (_wstETHAmount * exchangeRate) / ONE;
    }
}

contract TestWstETHOracle is Test {
    WstETHOracle oracle;
    uint256 wstETHPerStETH = 1139685405834714356;

    function setUp() public virtual {
        oracle = new WstETHOracle(address(new MockWstETH(wstETHPerStETH)));
    }

    function test_getDecimals() public {
        assertEq(oracle.decimals(), 18);
    }

    function test_getLatestRoundData() public {
        (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = oracle.latestRoundData();
        assertEq(roundId, 0);
        assertEq(answer, int256(wstETHPerStETH));
        assertEq(startedAt, 0);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, 0);
    }
}
