
pragma solidity ^0.8.21;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {FixedPriceOracle} from "periphery/FixedPriceOracle.sol";

contract DeployFixedPriceOracle is Script {
    function run()
        public
        returns (
            address deployedOracle
        )
    {
        address owner = vm.envAddress("OWNER");
        int256 price = vm.envInt("PRICE");
        uint8 decimals = uint8(vm.envUint("DECIMALS"));
        vm.startBroadcast();
        deployedOracle = address(new FixedPriceOracle(price, owner, decimals));
        vm.stopBroadcast();
        console.log(deployedOracle);
    }
}