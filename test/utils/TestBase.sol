// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";

contract TestBase is Test {
    address internal constant _WETH_ADDRESS =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant _WBTC_ADDRESS =
        0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant _USDC_ADDRESS =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    uint256 internal constant _ONE = 1e18;
    address internal constant _USER = address(0xabcdef);

    function _testWithDeployedContracts() internal returns (bool) {
        return vm.envOr("TEST_WITH_DEPLOYED_CONTRACTS", false);
    }
}
