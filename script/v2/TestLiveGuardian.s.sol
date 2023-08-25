// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {stdJson} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {Operation} from "src/v2/Types.sol";
import "src/v2/AeraVaultV2.sol";
import "forge-std/console.sol";

struct OperationAlpha {
    bytes data;
    address target;
    uint256 value;
}

contract TestGuardian is Test {
    using stdJson for string;

    address vaultAddress;
    AeraVaultV2 internal vault;
    Operation[] operations;

    function run() public {
        _loadOperations();
        vault = AeraVaultV2(payable(vaultAddress));
        vm.startPrank(vault.guardian());
        vault.submit(operations);
        vault.claim();
        vm.stopPrank();
    }

    function _loadOperations() internal {
        string memory path =
            string.concat(vm.projectRoot(), "/config/AeraVaultOperations.json");
        string memory json = vm.readFile(path);
        bytes memory vaultAddressRaw = json.parseRaw(".custodyAddress");
        vaultAddress = abi.decode(vaultAddressRaw, (address));
        bytes memory rawCalldatas = json.parseRaw(".calldatas");
        bytes[] memory calldatas = abi.decode(rawCalldatas, (bytes[]));
        bytes memory rawTargets = json.parseRaw(".targets");
        address[] memory targets = abi.decode(rawTargets, (address[]));

        for (uint256 i = 0; i < targets.length; i++) {
            operations.push(
                Operation({data: calldatas[i], target: targets[i], value: 0})
            );
        }
    }
}
