// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/Script.sol";
import {CurveOracle} from "periphery/CurveOracle.sol";
import {Script} from "forge-std/Script.sol";
contract DeployCurveOracleWrapper is Script {
    using stdJson for string;
    function run()
        public
        returns (address deployedWrapperAddress)
    {
        string memory path = string.concat(vm.projectRoot(), "/config/periphery/CurveOracleWrapper.json");
        string memory json = vm.readFile(path);
        address pool = json.readAddress(".pool");
        address tokenToPrice = json.readAddress(".tokenToPrice");
        address numeraireToken = json.readAddress(".numeraire");
        vm.startBroadcast();
        CurveOracle oracle = new CurveOracle(pool, tokenToPrice, numeraireToken);
        vm.stopBroadcast();
        deployedWrapperAddress = address(oracle);
    }
}
