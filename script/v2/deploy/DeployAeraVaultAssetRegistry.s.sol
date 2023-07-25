// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/IERC20.sol";
import {AeraVaultAssetRegistry} from "src/v2/AeraVaultAssetRegistry.sol";
import {IAssetRegistry} from "src/v2/interfaces/IAssetRegistry.sol";
import {DeployScriptBase} from "script/utils/DeployScriptBase.sol";

contract DeployScript is DeployScriptBase {
    using stdJson for string;

    function run() public returns (AeraVaultAssetRegistry deployed) {
        string memory path = string.concat(
            vm.projectRoot(), "/config/AeraVaultAssetRegistry.json"
        );
        string memory json = vm.readFile(path);

        bytes memory rawAssets = json.parseRaw(".assets");
        IAssetRegistry.AssetInformation[] memory assets =
            abi.decode(rawAssets, (IAssetRegistry.AssetInformation[]));
        uint256 numeraireId = json.readUint(".numeraireId");
        address feeToken = json.readAddress(".feeToken");

        vm.startBroadcast(_deployerPrivateKey);

        deployed =
            new AeraVaultAssetRegistry(assets, numeraireId, IERC20(feeToken));

        vm.stopBroadcast();

        console.logBytes(
            abi.encodePacked(
                type(AeraVaultAssetRegistry).creationCode,
                abi.encode(assets, numeraireId, feeToken)
            )
        );

        _checkIntegrity(deployed, assets, numeraireId, IERC20(feeToken));

        _storeDeployedAddress("assetRegistry", address(deployed));
    }

    function _checkIntegrity(
        AeraVaultAssetRegistry assetRegistry,
        IAssetRegistry.AssetInformation[] memory assets,
        uint256 numeraireId,
        IERC20 feeToken
    ) internal {
        uint256 numAssets = assets.length;

        IAssetRegistry.AssetInformation[] memory registeredAssets =
            assetRegistry.assets();

        assertEq(numAssets, registeredAssets.length);

        for (uint256 i = 0; i < numAssets; i++) {
            assertEq(
                address(registeredAssets[i].asset), address(assets[i].asset)
            );
            assertEq(registeredAssets[i].isERC4626, assets[i].isERC4626);
            assertEq(
                address(registeredAssets[i].oracle), address(assets[i].oracle)
            );
        }

        assertEq(numeraireId, assetRegistry.numeraireId());
        assertEq(address(feeToken), address(assetRegistry.feeToken()));
    }
}
