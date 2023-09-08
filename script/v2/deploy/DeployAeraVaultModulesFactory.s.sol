// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/Script.sol";
import {AeraVaultModulesFactory} from "src/v2/AeraVaultModulesFactory.sol";
import {DeployScriptBase} from "script/utils/DeployScriptBase.sol";

contract DeployScript is DeployScriptBase {
    using stdJson for string;

    /// @notice Deploy AeraVaultModulesFactory contract.
    /// @param deployed The address of deployed factory.
    function run() public returns (AeraVaultModulesFactory deployed) {
        _deployerAddress = msg.sender;
        string memory path = string.concat(
            vm.projectRoot(), "/config/AeraVaultModulesFactory.json"
        );
        string memory json = vm.readFile(path);

        address v2Factory = json.readAddress(".v2Factory");

        vm.startBroadcast(_deployerAddress);

        deployed = new AeraVaultModulesFactory(v2Factory);

        vm.stopBroadcast();

        console.logBytes(type(AeraVaultModulesFactory).creationCode);

        _storeDeployedAddress("modulesFactory", address(deployed));
    }
}
