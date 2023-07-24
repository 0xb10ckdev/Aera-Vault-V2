// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {stdJson} from "forge-std/Script.sol";
import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";

contract DeployScriptBase is Script, Test {
    using stdJson for string;

    uint256 internal _deployerPrivateKey;
    address internal _deployerAddress;

    constructor() {
        _deployerPrivateKey = uint256(vm.envBytes32("PRIVATE_KEY"));
        _deployerAddress = vm.addr(_deployerPrivateKey);
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
            try vm.parseJsonAddress(json, ".custody") returns (address addr) {
                vm.serializeAddress("Deployments", "custody", addr);
            } catch {}
            try vm.parseJsonAddress(json, ".hooks") returns (address addr) {
                vm.serializeAddress("Deployments", "hooks", addr);
            } catch {}
        } catch {}

        vm.writeJson(vm.serializeAddress("Deployments", key, deployed), path);
    }
}
