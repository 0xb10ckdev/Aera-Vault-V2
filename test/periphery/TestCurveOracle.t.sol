// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {console} from "forge-std/console.sol";
import {CurveOracle} from "periphery/CurveOracle.sol";
import {Test} from "forge-std/Test.sol";

contract MockCurvePool {
    address public immutable token0;
    address public immutable token1;
    uint256 public price_oracle;

    constructor(address token0_, address token1_) {
        token0 = token0_;
        token1 = token1_;
    }

    function coins(uint256 i) external view returns (address) {
        if (i == 0) {
            return token0;
        } else if (i == 1) {
            return token1;
        } else {
            revert();
        }
    }

    function setPrice(uint256 price) external {
        price_oracle = price;
    }
    
    function last_prices_timestamp() external view returns (uint256) {
        return block.timestamp;
    }
}

contract MockToken {
    uint8 public immutable decimals;
    string public symbol;

    constructor(uint8 decimals_, string memory symbol_) {
        decimals = decimals_;
        symbol = symbol_;
    }
}

contract TestCurveOracle is Test {
    MockToken WETH = new MockToken(18, "WETH");
    MockToken USDC = new MockToken(6, "USDC");
    MockToken T = new MockToken(18, "T");
    MockToken FIVE = new MockToken(5, "FIVE");

    address weth = address(WETH);
    address usdc = address(USDC);
    address t = address(T);
    address five = address(FIVE);

    MockCurvePool TETH = new MockCurvePool(weth, t);
    address teth = address(TETH);

    CurveOracle oracle;

    function setUp() public virtual {
        vm.label(weth, "WETH");
        vm.label(usdc, "USDC");
        vm.label(t, "T");
        vm.label(teth, "teth");

        // Curve's price oracle always returns 18 decimals, and the quote token
        // is coin(0). So, for this pool, the price should be something like
        // 0.00001115432081 WETH per T
        TETH.setPrice(11445770788619);
    }

    function testThatCorrectPriceIsReturned() public {
        // This is a test showing that we've recreated what's on
        // chain as of 2023-09-20.
        oracle = new CurveOracle(teth);

        (, int256 answer,,,) = oracle.latestRoundData();
        assertEq(answer, int256(TETH.price_oracle()));
    }

    function testThatBlockTimestampIsAlwaysReturned() public {
        oracle = new CurveOracle(teth);
        (,,, uint256 updatedAt,) = oracle.latestRoundData();
        assertEq(updatedAt, block.timestamp);

        // Jump ahead. Confirm that the updatedAt timestamp is actually updated.
        uint256 nextTime = block.timestamp + 100 seconds;
        vm.warp(nextTime);
        (,,, updatedAt,) = oracle.latestRoundData();
        assertEq(nextTime, block.timestamp);
        assertEq(updatedAt, block.timestamp);
    }

    function testThatPriceRespectsDecimals() public {
        MockCurvePool POOL = new MockCurvePool(t, usdc);
        POOL.setPrice(20e18); // 1 USDC is worth 20 T
        address pool = address(POOL);

        oracle = new CurveOracle(pool);
        (, int256 answer,,,) = oracle.latestRoundData();
        assertEq(answer, int256(20e18));
    }
}
