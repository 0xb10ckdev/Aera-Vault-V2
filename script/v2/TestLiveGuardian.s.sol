// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {Operation} from "src/v2/Types.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/interfaces/IAssetRegistry.sol";
import "forge-std/console.sol";

contract TestGuardian is Test {
    using stdJson for string;

    address vaultAddress;
    AeraVaultV2 internal vault;
    Operation[] operations;

    function run() public {
        _loadOperations();
        vault = AeraVaultV2(payable(vaultAddress));
        address guardian = vault.guardian();
        IERC20 feeToken = IAssetRegistry(vault.assetRegistry()).feeToken();
        vm.startPrank(guardian);
        vault.submit(operations);
        uint256 fees = Math.min(feeToken.balanceOf(address(vault)), vault.fees(guardian));
        console2.log("Available fees for guardian", fees);
        if (fees > 0) {
            uint256 beforeBalance = feeToken.balanceOf(guardian);
            vault.claim();
            uint256 afterBalance = feeToken.balanceOf(guardian);
            console2.log("Claimed fees", afterBalance - beforeBalance);
        }
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
