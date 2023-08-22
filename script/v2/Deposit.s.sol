// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/Script.sol";
import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {AssetValue} from "src/v2/Types.sol";
import "src/v2/AeraVaultV2.sol";

contract Deposit is Script, Test {
    using stdJson for string;

    address internal vaultAddress;
    AeraVaultV2 internal vault;

    function run() public {
        string memory path =
            string.concat(vm.projectRoot(), "/config/AeraVaultDeposit.json");
        string memory json = vm.readFile(path);

        vaultAddress = json.readAddress(".vaultAddress");
        vault = AeraVaultV2(payable(vaultAddress));

        bytes memory rawDepositAmounts = json.parseRaw(".depositAmounts");
        AssetValue[] memory depositAmounts =
            abi.decode(rawDepositAmounts, (AssetValue[]));

        vm.startBroadcast();
        for (uint256 i = 0; i < depositAmounts.length; i++) {
            depositAmounts[i].asset.approve(
                vaultAddress, depositAmounts[i].value
            );
        }
        vault.deposit(depositAmounts);
        vm.stopBroadcast();
    }
}
