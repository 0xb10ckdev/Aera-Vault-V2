// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/Script.sol";
import {AeraVaultV2Factory} from "src/v2/AeraVaultV2Factory.sol";
import {DeployScriptBase} from "script/utils/DeployScriptBase.sol";

contract DeployScript is DeployScriptBase {
    using stdJson for string;

    /// @notice Deploy AeraVaultV2Factory contract.
    /// @param deployed The address of deployed factory.
    function run() public returns (AeraVaultV2Factory deployed) {
        _deployerAddress = msg.sender;
        string memory path =
            string.concat(vm.projectRoot(), "/config/AeraVaultV2Factory.json");
        string memory json = vm.readFile(path);

        address weth = json.readAddress(".weth");

        vm.startBroadcast(_deployerAddress);

        deployed = new AeraVaultV2Factory(weth);

        vm.stopBroadcast();

        console.logBytes(type(AeraVaultV2Factory).creationCode);

        _storeDeployedAddress("factory", address(deployed));
    }
}
