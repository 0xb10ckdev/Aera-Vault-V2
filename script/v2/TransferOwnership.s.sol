// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import "src/v2/AeraVaultV2.sol";

contract TransferOwnership is Script {
    function run() public {
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        address newOwner = vm.envAddress("NEW_OWNER");
        AeraVaultV2 vault = AeraVaultV2(payable(vaultAddress));
        vm.startBroadcast();
        vault.transferOwnership(newOwner);
        vm.stopBroadcast();
    }
}
