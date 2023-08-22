// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import "src/v2/AeraVaultV2.sol";

contract Resume is Script {
    function run() public {
        address vaultAddress = vm.envAddress("VAULT_ADDRESS");
        AeraVaultV2 vault = AeraVaultV2(payable(vaultAddress));
        vm.startBroadcast();
        vault.resume();
        vm.stopBroadcast();
    }
}
