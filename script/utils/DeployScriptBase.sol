// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {stdJson} from "forge-std/Script.sol";
import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";

contract DeployScriptBase is Script, Test {
    using stdJson for string;

    // subclasses need to set this to msg.sender
    address internal _deployerAddress;

    function setDeployerAddress(address deployerAddress) public {
        _deployerAddress = deployerAddress;
    }

    function _storeDeployedAddress(
        string memory key,
        address deployed
    ) internal {
        string memory path =
            string.concat(vm.projectRoot(), "/config/Deployments.json");

        try vm.readFile(path) returns (string memory json) {
            try vm.parseJsonAddress(json, ".assetRegistry") returns (
                address addr
            ) {
                vm.serializeAddress("Deployments", "assetRegistry", addr);
            } catch {}
            try vm.parseJsonAddress(json, ".factory") returns (address addr) {
                vm.serializeAddress("Deployments", "factory", addr);
            } catch {}
            try vm.parseJsonAddress(json, ".vault") returns (address addr) {
                vm.serializeAddress("Deployments", "vault", addr);
            } catch {}
            try vm.parseJsonAddress(json, ".hooks") returns (address addr) {
                vm.serializeAddress("Deployments", "hooks", addr);
            } catch {}
            try vm.parseJsonAddress(json, ".modulesFactory") returns (
                address addr
            ) {
                vm.serializeAddress("Deployments", "modulesFactory", addr);
            } catch {}
        } catch {}

        vm.writeJson(vm.serializeAddress("Deployments", key, deployed), path);
    }
}
