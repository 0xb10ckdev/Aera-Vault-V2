// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/Script.sol";
import {AeraVaultV2} from "src/v2/AeraVaultV2.sol";
import {IAeraVaultV2Factory} from "src/v2/interfaces/IAeraVaultV2Factory.sol";
import {DeployScriptBase} from "script/utils/DeployScriptBase.sol";

contract DeployScript is DeployScriptBase {
    using stdJson for string;

    function run() public returns (AeraVaultV2 deployed) {
        string memory path =
            string.concat(vm.projectRoot(), "/config/AeraVaultV2.json");
        string memory json = vm.readFile(path);

        address aeraVaultV2Factory = json.readAddress(".aeraVaultV2Factory");
        address assetRegistry = json.readAddress(".assetRegistry");
        address guardian = json.readAddress(".guardian");
        address feeRecipient = json.readAddress(".feeRecipient");
        uint256 fee = json.readUint(".fee");

        vm.startBroadcast(_deployerPrivateKey);

        deployed = IAeraVaultV2Factory(aeraVaultV2Factory).create(
            assetRegistry, guardian, feeRecipient, fee
        );

        vm.stopBroadcast();

        console.logBytes(
            abi.encodeWithSelector(
                IAeraVaultV2Factory.create.selector,
                assetRegistry,
                guardian,
                feeRecipient,
                fee
            )
        );

        _checkIntegrity(deployed, assetRegistry, guardian, feeRecipient, fee);

        _storeDeployedAddress("custody", address(deployed));
    }

    function _checkIntegrity(
        AeraVaultV2 vault,
        address assetRegistry,
        address guardian,
        address feeRecipient,
        uint256 fee
    ) internal {
        assertEq(address(vault.assetRegistry()), address(assetRegistry));
        assertEq(vault.guardian(), guardian);
        assertEq(vault.feeRecipient(), feeRecipient);
        assertEq(vault.fee(), fee);
    }
}
