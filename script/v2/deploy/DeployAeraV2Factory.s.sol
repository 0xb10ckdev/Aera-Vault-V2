// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/Script.sol";
import {AeraV2Factory} from "src/v2/AeraV2Factory.sol";
import {DeployScriptBase} from "script/utils/DeployScriptBase.sol";

contract DeployAeraV2Factory is DeployScriptBase {
    using stdJson for string;

    /// @notice Deploy AeraV2Factory contract.
    /// @param deployed The address of deployed factory.
    function run() public returns (AeraV2Factory deployed) {
        if (_deployerAddress == address(0)) {
            _deployerAddress = msg.sender;
        }
        string memory path =
            string.concat(vm.projectRoot(), "/config/AeraV2Factory.json");
        string memory json = vm.readFile(path);

        address wrappedNativeToken = json.readAddress(".wrappedNativeToken");

        vm.startBroadcast(_deployerAddress);

        deployed = new AeraV2Factory(wrappedNativeToken);

        vm.stopBroadcast();

        //console.logBytes(type(AeraV2Factory).creationCode);

        _storeDeployedAddress("factory", address(deployed));
    }
}
