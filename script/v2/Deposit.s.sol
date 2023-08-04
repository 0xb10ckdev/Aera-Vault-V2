// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/Script.sol";
import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {AssetValue} from "src/v2/Types.sol";
import "src/v2/AeraVaultV2.sol";

contract DeployScriptBase is Script, Test {
    using stdJson for string;

    uint256 internal senderPrivateKey;
    address internal senderAddress;
    address internal vaultAddress;
    AeraVaultV2 internal vault;

    constructor() {
        senderPrivateKey = uint256(vm.envOr("PRIVATE_KEY", bytes32(0)));

        if (senderPrivateKey == 0) {
            string memory mnemonic = vm.envString("MNEMONIC");
            senderPrivateKey = vm.deriveKey(mnemonic, 1);
        }

        senderAddress = vm.addr(senderPrivateKey);
    }

    function run() public {
        string memory path =
            string.concat(vm.projectRoot(), "/config/AeraVaultDeposit.json");
        string memory json = vm.readFile(path);

        vaultAddress = json.readAddress(".vaultAddress");
        vault = AeraVaultV2(vaultAddress);

        bytes memory rawDepositAmounts = json.parseRaw(".depositAmounts");
        AssetValue[] memory depositAmounts =
            abi.decode(rawDepositAmounts, (AssetValue[]));

        vm.startBroadcast(senderPrivateKey);
        for (uint256 i = 0; i < depositAmounts.length; i++) {
            depositAmounts[i].asset.approve(
                vaultAddress, depositAmounts[i].value
            );
        }
        vault.deposit(depositAmounts);
        vm.stopBroadcast();
    }
}
