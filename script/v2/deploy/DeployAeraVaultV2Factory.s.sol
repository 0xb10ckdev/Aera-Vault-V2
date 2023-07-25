// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {AeraVaultV2Factory} from "src/v2/AeraVaultV2Factory.sol";
import {DeployScriptBase} from "script/utils/DeployScriptBase.sol";

contract DeployScript is DeployScriptBase {
    function run() public returns (AeraVaultV2Factory deployed) {
        vm.startBroadcast(_deployerPrivateKey);

        deployed = new AeraVaultV2Factory();

        vm.stopBroadcast();

        console.logBytes(type(AeraVaultV2Factory).creationCode);

        _storeDeployedAddress("factory", address(deployed));
    }
}
