// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/AeraVaultHooks.sol";
import "src/v2/AeraVaultAssetRegistry.sol";

contract TransferOwnership is Script {
    function run() public {
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        address newOwner = vm.envAddress("NEW_OWNER");
        AeraVaultV2 vault = AeraVaultV2(payable(vaultAddress));
        AeraVaultHooks hooks = AeraVaultHooks(address(vault.hooks()));
        AeraVaultAssetRegistry assetRegistry = AeraVaultAssetRegistry(address(vault.assetRegistry()));
        vm.startBroadcast();
        vault.transferOwnership(newOwner);
        hooks.transferOwnership(newOwner);
        assetRegistry.transferOwnership(newOwner);
        vm.stopBroadcast();
    }
}
