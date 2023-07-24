// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/Script.sol";
import {AeraVaultHooks} from "src/v2/AeraVaultHooks.sol";
import {AeraVaultV2} from "src/v2/AeraVaultV2.sol";
import {TargetSighash} from "src/v2/Types.sol";
import {DeployScriptBase} from "script/utils/DeployScriptBase.sol";

contract DeployScript is DeployScriptBase {
    using stdJson for string;

    function run() public returns (AeraVaultHooks deployed) {
        string memory path =
            string.concat(vm.projectRoot(), "/config/AeraVaultHooks.json");
        string memory json = vm.readFile(path);

        address custody = json.readAddress(".custody");
        uint256 maxDailyExecutionLoss = json.readUint(".maxDailyExecutionLoss");
        uint256[] memory allowlist =
            json.readUintArray(".targetSighashAllowlist");

        TargetSighash[] memory targetSighashAllowlist;
        assembly {
            targetSighashAllowlist := allowlist
        }

        vm.startBroadcast(_deployerPrivateKey);

        deployed = new AeraVaultHooks(
            custody,
            maxDailyExecutionLoss,
            targetSighashAllowlist
        );

        AeraVaultV2(custody).setHooks(address(deployed));

        vm.stopBroadcast();

        console.logBytes(
            abi.encodePacked(
                type(AeraVaultHooks).creationCode,
                abi.encode(maxDailyExecutionLoss, targetSighashAllowlist)
            )
        );
        console.logBytes(
            abi.encodeWithSelector(
                AeraVaultV2.setHooks.selector, address(deployed)
            )
        );

        _checkIntegrity(
            deployed, custody, maxDailyExecutionLoss, targetSighashAllowlist
        );

        _storeDeployedAddress("hooks", address(deployed));
    }

    function _checkIntegrity(
        AeraVaultHooks hooks,
        address custody,
        uint256 maxDailyExecutionLoss,
        TargetSighash[] memory targetSighashAllowlist
    ) internal {
        assertEq(address(hooks.custody()), custody);
        assertEq(hooks.maxDailyExecutionLoss(), maxDailyExecutionLoss);
        assertEq(hooks.currentDay(), block.timestamp / 1 days);
        assertEq(hooks.cumulativeDailyMultiplier(), 1e18);

        uint256 numTargetSighashAllowlist = targetSighashAllowlist.length;

        for (uint256 i = 0; i < numTargetSighashAllowlist; i++) {
            assertTrue(hooks.targetSighashAllowed(targetSighashAllowlist[i]));
        }
    }
}
