// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {stdJson} from "forge-std/Script.sol";
import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";

contract DeployScriptBase is Script, Test {
    using stdJson for string;

    uint256 internal _deployerPrivateKey;
    address internal _deployerAddress;

    constructor(bool loadDeployerAddressFromPrivateKey) {
        if (loadDeployerAddressFromPrivateKey) {
            _loadDeployerAddressFromPrivateKey();
        }
    }

    function _loadDeployerAddressFromPrivateKey() internal {
        _deployerPrivateKey = uint256(vm.envOr("PRIVATE_KEY", bytes32(0)));

        if (_deployerPrivateKey == 0) {
            string memory mnemonic = vm.envString("MNEMONIC");
            _deployerPrivateKey = vm.deriveKey(mnemonic, 0);
        }

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
