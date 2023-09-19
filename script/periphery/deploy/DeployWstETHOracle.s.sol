// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {console} from "forge-std/console.sol";
import {WstETHOracle} from "periphery/WstETHOracle.sol";
import {Script} from "forge-std/Script.sol";
contract DeployWstETHOracle is Script {
    address wstETHMainnet = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    function run()
        public
        returns (address deployedOracleAddress)
    {
        vm.startBroadcast();
        WstETHOracle oracle = new WstETHOracle(wstETHMainnet);
        vm.stopBroadcast();
        deployedOracleAddress = address(oracle);
    }
}