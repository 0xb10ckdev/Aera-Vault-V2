// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/Script.sol";
import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {AssetValue} from "src/v2/Types.sol";
import "src/v2/AeraVaultV2.sol";

contract Withdraw is Script, Test {
    using stdJson for string;

    address internal vaultAddress;
    AeraVaultV2 internal vault;

    function run() public {
        string memory path =
            string.concat(vm.projectRoot(), "/config/AeraVaultWithdraw.json");
        string memory json = vm.readFile(path);

        vaultAddress = json.readAddress(".vaultAddress");
        vault = AeraVaultV2(payable(vaultAddress));

        bytes memory rawWithdrawAmounts = json.parseRaw(".withdrawAmounts");
        AssetValue[] memory withdrawAmounts =
            abi.decode(rawWithdrawAmounts, (AssetValue[]));

        vm.startBroadcast();
        vault.withdraw(withdrawAmounts);
        vm.stopBroadcast();
    }
}
