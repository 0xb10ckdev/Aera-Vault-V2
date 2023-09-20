// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;
import {DeployConstants} from "script/utils/DeployConstants.sol";
import {CurveOracle} from "periphery/CurveOracle.sol";
import {Script} from "forge-std/Script.sol";
contract DeployTETHCurveOracle is Script, DeployConstants {
    function run()
        public
        returns (address deployedAddress)
    {
        address pool = teth;
        address baseToken = weth;
        address quoteToken = T;
        vm.startBroadcast();
        CurveOracle oracle = new CurveOracle(pool, baseToken, quoteToken);
        vm.stopBroadcast();
        deployedAddress = address(oracle);
    }
}
