// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {console} from "forge-std/console.sol";
import {CurveOracleWrapper} from "periphery/CurveOracleWrapper.sol";
import {Test} from "forge-std/Test.sol";

contract TestCurveOracleWrapper is Test {
    address pool = 0x752eBeb79963cf0732E9c0fec72a49FD1DEfAEAC;
    address tToken = 0xCdF7028ceAB81fA0C6971208e83fa7872994beE5;
    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    CurveOracleWrapper oracleWrapper;

    modifier whenValidNetwork() {
        if (this.getChainID() != 1) {
            return;
        }
        _;
    }

    function setUp() public virtual whenValidNetwork {
        vm.label(pool, "Pool");
        vm.label(weth, "WETH");
        vm.label(tToken, "TToken");
        
        vm.roll(18130619);

        oracleWrapper = new CurveOracleWrapper(pool, tToken, weth);
    }

    function test_getDecimals() public whenValidNetwork {
        assertEq(oracleWrapper.decimals(), 18);
    }
    function test_getLatestRoundData() public whenValidNetwork {
        (
            uint80 roundId, 
            int256 answer, 
            uint256 startedAt, 
            uint256 updatedAt, 
            uint80 answeredInRound
        ) = oracleWrapper.latestRoundData();
        assertEq(roundId, 0);
        assertEq(answer, 95891321380667741120450); // ~95k tToken for 1 ETH
        assertEq(startedAt, 0);
        assertEq(updatedAt, block.timestamp);
        assertEq(answeredInRound, 0);
    }

    function getChainID() external view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }
}