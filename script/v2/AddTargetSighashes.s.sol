// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {console} from "forge-std/console.sol";
import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/Script.sol";
import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {AssetValue} from "src/v2/Types.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/AeraVaultHooks.sol";

contract AddTargetSigHashes is Script, Test {
    using stdJson for string;

    AeraVaultHooks internal hooks;

    function run() public {
        string memory path = string.concat(
            vm.projectRoot(), "/config/AeraVaultAddTargetSighashes.json"
        );
        string memory json = vm.readFile(path);

        hooks = AeraVaultHooks(json.readAddress(".hooksAddress"));

        bytes memory rawSelectors = json.parseRaw(".selectors");
        bytes[] memory selectors = abi.decode(rawSelectors, (bytes[]));
        bytes4[] memory bytes4Selectors = new bytes4[](selectors.length);
        for (uint256 i = 0; i < selectors.length; i++) {
            bytes4Selectors[i] = bytes4(abi.encodePacked(selectors[i]));
        }

        bytes memory rawTargets = json.parseRaw(".selectors");
        address[] memory targets = abi.decode(rawTargets, (address[]));

        vm.startBroadcast();
        for (uint256 i = 0; i < targets.length; i++) {
            hooks.addTargetSighash(targets[i], bytes4Selectors[i]);
        }
        vm.stopBroadcast();
    }
}
