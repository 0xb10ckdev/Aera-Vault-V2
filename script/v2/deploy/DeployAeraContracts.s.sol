// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/Console.sol";
import {stdJson} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/IERC20.sol";
import {AeraVaultAssetRegistry} from "src/v2/AeraVaultAssetRegistry.sol";
import {AeraVaultHooks} from "src/v2/AeraVaultHooks.sol";
import {AeraVaultV2} from "src/v2/AeraVaultV2.sol";
import {AeraVaultV2Factory} from "src/v2/AeraVaultV2Factory.sol";
import {IAssetRegistry} from "src/v2/interfaces/IAssetRegistry.sol";
import {TargetSighash} from "src/v2/Types.sol";
import {DeployScriptBase} from "script/utils/DeployScriptBase.sol";
import {Aeraform} from "script/utils/Aeraform.sol";

contract DeployScript is DeployScriptBase {
    using stdJson for string;

    bytes32 internal _salt;

    function run(bytes32 salt)
        public
        returns (
            address deployedAssetRegistry,
            address deployedCustody,
            address deployedHooks
        )
    {
        _salt = salt;

        // Get parameters for AssetRegistry
        (
            IAssetRegistry.AssetInformation[] memory assets,
            uint256 numeraireId,
            address feeToken
        ) = _getAssetRegistryParams();

        // Get parameters for AeraVaultV2
        (
            address aeraVaultV2Factory,
            address guardian,
            address feeRecipient,
            uint256 fee
        ) = _getAeraVaultV2Params();

        // Get parameters for AeraVaultHooks
        (
            uint256 maxDailyExecutionLoss,
            TargetSighash[] memory targetSighashAllowlist
        ) = _getAeraVaultHooksParams();

        vm.startBroadcast(_deployerPrivateKey);

        // Deploy AssetRegistry
        deployedAssetRegistry =
            _deployAssetRegistry(assets, numeraireId, feeToken);

        // Deploy AeraVaultV2
        deployedCustody = _deployAeraVaultV2(
            aeraVaultV2Factory,
            deployedAssetRegistry,
            guardian,
            feeRecipient,
            fee
        );

        // Deploy AeraVaultHooks
        deployedHooks = _deployAeraVaultHooks(
            deployedCustody, maxDailyExecutionLoss, targetSighashAllowlist
        );

        AeraVaultV2 vault = AeraVaultV2(deployedCustody);

        if (address(vault.assetRegistry()) != deployedAssetRegistry) {
            vault.setAssetRegistry(deployedAssetRegistry);
        }
        if (address(vault.hooks()) != deployedHooks) {
            vault.setHooks(deployedHooks);
        }

        vm.stopBroadcast();

        // Check deployed contracts

        _checkAssetRegistryIntegrity(
            AeraVaultAssetRegistry(deployedAssetRegistry),
            assets,
            numeraireId,
            feeToken
        );

        _checkAeraVaultV2Integrity(
            vault, deployedAssetRegistry, guardian, feeRecipient, fee
        );

        _checkAeraVaultHooksIntegrity(
            AeraVaultHooks(deployedHooks),
            deployedCustody,
            maxDailyExecutionLoss,
            targetSighashAllowlist
        );

        // Store deployed addresses

        _storeDeployedAddress("assetRegistry", deployedAssetRegistry);
        _storeDeployedAddress("custody", deployedCustody);
        _storeDeployedAddress("hooks", deployedHooks);
    }

    function _getAssetRegistryParams()
        internal
        returns (
            IAssetRegistry.AssetInformation[] memory assets,
            uint256 numeraireId,
            address feeToken
        )
    {
        string memory path = string.concat(
            vm.projectRoot(), "/config/AeraVaultAssetRegistry.json"
        );
        string memory json = vm.readFile(path);

        bytes memory rawAssets = json.parseRaw(".assets");

        assets = abi.decode(rawAssets, (IAssetRegistry.AssetInformation[]));
        numeraireId = json.readUint(".numeraireId");
        feeToken = json.readAddress(".feeToken");
    }

    function _getAeraVaultV2Params()
        internal
        returns (
            address aeraVaultV2Factory,
            address guardian,
            address feeRecipient,
            uint256 fee
        )
    {
        string memory path =
            string.concat(vm.projectRoot(), "/config/AeraVaultV2.json");
        string memory json = vm.readFile(path);

        aeraVaultV2Factory = json.readAddress(".aeraVaultV2Factory");
        guardian = json.readAddress(".guardian");
        feeRecipient = json.readAddress(".feeRecipient");
        fee = json.readUint(".fee");
    }

    function _getAeraVaultHooksParams()
        internal
        returns (
            uint256 maxDailyExecutionLoss,
            TargetSighash[] memory targetSighashAllowlist
        )
    {
        string memory path =
            string.concat(vm.projectRoot(), "/config/AeraVaultHooks.json");
        string memory json = vm.readFile(path);

        maxDailyExecutionLoss = json.readUint(".maxDailyExecutionLoss");

        uint256[] memory allowlist =
            json.readUintArray(".targetSighashAllowlist");

        assembly {
            targetSighashAllowlist := allowlist
        }
    }

    function _deployAssetRegistry(
        IAssetRegistry.AssetInformation[] memory assets,
        uint256 numeraireId,
        address feeToken
    ) internal returns (address deployed) {
        bytes memory bytecode = abi.encodePacked(
            type(AeraVaultAssetRegistry).creationCode,
            abi.encode(_deployerAddress, assets, numeraireId, feeToken)
        );

        deployed = Aeraform.idempotentDeploy(_salt, bytecode);
    }

    function _deployAeraVaultV2(
        address aeraVaultV2Factory,
        address assetRegistry,
        address guardian,
        address feeRecipient,
        uint256 fee
    ) internal returns (address deployed) {
        deployed = AeraVaultV2Factory(aeraVaultV2Factory).computeAddress(
            _salt, _deployerAddress, assetRegistry, guardian, feeRecipient, fee
        );

        uint256 size;
        assembly {
            size := extcodesize(deployed)
        }

        if (size == 0) {
            AeraVaultV2Factory(aeraVaultV2Factory).create(
                _salt,
                _deployerAddress,
                assetRegistry,
                guardian,
                feeRecipient,
                fee
            );
        }
    }

    function _deployAeraVaultHooks(
        address custody,
        uint256 maxDailyExecutionLoss,
        TargetSighash[] memory targetSighashAllowlist
    ) internal returns (address deployed) {
        bytes memory bytecode = abi.encodePacked(
            type(AeraVaultHooks).creationCode,
            abi.encode(
                _deployerAddress,
                custody,
                maxDailyExecutionLoss,
                targetSighashAllowlist
            )
        );

        deployed = Aeraform.idempotentDeploy(_salt, bytecode);
    }

    function _checkAssetRegistryIntegrity(
        AeraVaultAssetRegistry assetRegistry,
        IAssetRegistry.AssetInformation[] memory assets,
        uint256 numeraireId,
        address feeToken
    ) internal {
        console.log("Checking Asset Registry Integrity");

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
        assertEq(feeToken, address(assetRegistry.feeToken()));

        console.log("Checked Asset Registry Integrity");
    }

    function _checkAeraVaultV2Integrity(
        AeraVaultV2 vault,
        address assetRegistry,
        address guardian,
        address feeRecipient,
        uint256 fee
    ) internal {
        console.log("Checking Aera Vault V2 Integrity");

        assertEq(address(vault.assetRegistry()), address(assetRegistry));
        assertEq(vault.guardian(), guardian);
        assertEq(vault.feeRecipient(), feeRecipient);
        assertEq(vault.fee(), fee);

        console.log("Checked Aera Vault V2 Integrity");
    }

    function _checkAeraVaultHooksIntegrity(
        AeraVaultHooks hooks,
        address custody,
        uint256 maxDailyExecutionLoss,
        TargetSighash[] memory targetSighashAllowlist
    ) internal {
        console.log("Checking Hooks Integrity");

        assertEq(address(hooks.custody()), custody);
        assertEq(hooks.maxDailyExecutionLoss(), maxDailyExecutionLoss);
        assertEq(hooks.currentDay(), block.timestamp / 1 days);
        assertEq(hooks.cumulativeDailyMultiplier(), 1e18);

        uint256 numTargetSighashAllowlist = targetSighashAllowlist.length;

        for (uint256 i = 0; i < numTargetSighashAllowlist; i++) {
            assertTrue(hooks.targetSighashAllowed(targetSighashAllowlist[i]));
        }

        console.log("Checked Hooks Integrity");
    }
}
