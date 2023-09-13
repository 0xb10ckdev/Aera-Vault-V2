// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {console} from "forge-std/console.sol";
import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/Script.sol";
import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import "src/v2/AeraVaultV2.sol";
import {IAssetRegistry} from "src/v2/interfaces/IAssetRegistry.sol";
import {AeraVaultAssetRegistry} from "src/v2/AeraVaultAssetRegistry.sol";

contract RemoveAssetsFromRegistry is Script, Test {
    using stdJson for string;

    AeraVaultAssetRegistry internal assetRegistry;
    AeraVaultV2 internal vault;

    function run() public {
        string memory path = string.concat(
            vm.projectRoot(), "/config/RemoveAssetsFromRegistry.json"
        );
        string memory json = vm.readFile(path);

        bytes memory rawAssets = json.parseRaw(".assets");
        address[] memory assets = abi.decode(rawAssets, (address[]));
        vault = AeraVaultV2(payable(json.readAddress(".vault")));
        assetRegistry = AeraVaultAssetRegistry(address(vault.assetRegistry()));

        vm.startBroadcast();
        for (uint256 i = 0; i < assets.length; i++) {
            assetRegistry.removeAsset(assets[i]);
        }
        vm.stopBroadcast();
    }
}
