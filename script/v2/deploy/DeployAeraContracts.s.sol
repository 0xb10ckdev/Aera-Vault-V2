// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
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

    /// @notice Deploy AssetRegistry, AeraVaultV2 and Hooks with the given salt
    ///         if they were not deployed yet.
    /// @param salt The salt value to create contract.
    /// @return deployedAssetRegistry The address of deployed AssetRegistry.
    /// @return deployedCustody The address of deployed AeraVaultV2.
    /// @return deployedHooks The address of deployed Hooks.
    function run(bytes32 salt)
        public
        returns (
            address deployedAssetRegistry,
            address deployedCustody,
            address deployedHooks
        )
    {
        _salt = salt;

        vm.startBroadcast(_deployerPrivateKey);

        // Deploy AssetRegistry
        deployedAssetRegistry = _deployAssetRegistry();

        // Deploy AeraVaultV2
        deployedCustody = _deployAeraVaultV2(deployedAssetRegistry);

        // Deploy AeraVaultHooks
        deployedHooks = _deployAeraVaultHooks(deployedCustody);

        // Link modules
        _linkModules(deployedAssetRegistry, deployedCustody, deployedHooks);

        vm.stopBroadcast();
    }

    function _getAssetRegistryParams()
        internal
        returns (
            address owner,
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

        owner = json.readAddress(".owner");
        assets = abi.decode(rawAssets, (IAssetRegistry.AssetInformation[]));
        numeraireId = json.readUint(".numeraireId");
        feeToken = json.readAddress(".feeToken");
    }

    function _getAeraVaultV2Params()
        internal
        returns (
            address aeraVaultV2Factory,
            address owner,
            address guardian,
            address feeRecipient,
            uint256 fee,
            string memory description
        )
    {
        string memory path =
            string.concat(vm.projectRoot(), "/config/AeraVaultV2.json");
        string memory json = vm.readFile(path);

        aeraVaultV2Factory = json.readAddress(".aeraVaultV2Factory");
        owner = json.readAddress(".owner");
        guardian = json.readAddress(".guardian");
        feeRecipient = json.readAddress(".feeRecipient");
        fee = json.readUint(".fee");
        description = json.readString(".description");
    }

    function _getAeraVaultHooksParams()
        internal
        returns (
            address owner,
            uint256 maxDailyExecutionLoss,
            TargetSighash[] memory targetSighashAllowlist
        )
    {
        string memory path =
            string.concat(vm.projectRoot(), "/config/AeraVaultHooks.json");
        string memory json = vm.readFile(path);

        owner = json.readAddress(".owner");
        maxDailyExecutionLoss = json.readUint(".maxDailyExecutionLoss");

        uint256[] memory allowlist =
            json.readUintArray(".targetSighashAllowlist");

        assembly {
            targetSighashAllowlist := allowlist
        }
    }

    function _deployAssetRegistry() internal returns (address deployed) {
        // Get parameters for AssetRegistry
        (
            address owner,
            IAssetRegistry.AssetInformation[] memory assets,
            uint256 numeraireId,
            address feeToken
        ) = _getAssetRegistryParams();

        // Get bytecode
        bytes memory bytecode = abi.encodePacked(
            type(AeraVaultAssetRegistry).creationCode,
            abi.encode(
                owner == address(0) ? _deployerAddress : owner,
                assets,
                numeraireId,
                feeToken
            )
        );

        // Deploy AssetRegistry
        deployed = Aeraform.idempotentDeploy(_salt, bytecode);

        // Check deployed AssetRegistry
        _checkAssetRegistryIntegrity(
            AeraVaultAssetRegistry(deployed), assets, numeraireId, feeToken
        );

        // Store deployed address
        _storeDeployedAddress("assetRegistry", deployed);
    }

    function _deployAeraVaultV2(address assetRegistry)
        internal
        returns (address deployed)
    {
        // Get parameters for AeraVaultV2
        (
            address aeraVaultV2Factory,
            address owner,
            address guardian,
            address feeRecipient,
            uint256 fee,
            string memory description
        ) = _getAeraVaultV2Params();

        deployed = AeraVaultV2Factory(aeraVaultV2Factory).computeAddress(
            _salt,
            owner == address(0) ? _deployerAddress : owner,
            assetRegistry,
            guardian,
            feeRecipient,
            fee,
            description
        );

        uint256 size;
        assembly {
            size := extcodesize(deployed)
        }

        // Deploy AeraVaultV2
        if (size == 0) {
            AeraVaultV2Factory(aeraVaultV2Factory).create(
                _salt,
                owner == address(0) ? _deployerAddress : owner,
                assetRegistry,
                guardian,
                feeRecipient,
                fee,
                description
            );
        }

        // Check deployed AeraVaultV2
        _checkAeraVaultV2Integrity(
            deployed, assetRegistry, guardian, feeRecipient, fee, description
        );

        // Store deployed address
        _storeDeployedAddress("custody", deployed);
    }

    function _deployAeraVaultHooks(address custody)
        internal
        returns (address deployed)
    {
        // Get parameters for AeraVaultHooks
        (
            address owner,
            uint256 maxDailyExecutionLoss,
            TargetSighash[] memory targetSighashAllowlist
        ) = _getAeraVaultHooksParams();

        // Get bytecode
        bytes memory bytecode = abi.encodePacked(
            type(AeraVaultHooks).creationCode,
            abi.encode(
                owner == address(0) ? _deployerAddress : owner,
                custody,
                maxDailyExecutionLoss,
                targetSighashAllowlist
            )
        );

        // Deploy AeraVaultHooks
        deployed = Aeraform.idempotentDeploy(_salt, bytecode);

        // Check deployed AeraVaultHooks
        _checkAeraVaultHooksIntegrity(
            AeraVaultHooks(deployed),
            custody,
            maxDailyExecutionLoss,
            targetSighashAllowlist
        );

        // Store deployed address
        _storeDeployedAddress("hooks", deployed);
    }

    function _linkModules(
        address deployedAssetRegistry,
        address deployedCustody,
        address deployedHooks
    ) internal {
        AeraVaultV2 vault = AeraVaultV2(deployedCustody);

        if (address(vault.assetRegistry()) != deployedAssetRegistry) {
            vault.setAssetRegistry(deployedAssetRegistry);
        }
        if (address(vault.hooks()) != deployedHooks) {
            vault.setHooks(deployedHooks);
        }
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
        address deployedAeraVault,
        address assetRegistry,
        address guardian,
        address feeRecipient,
        uint256 fee,
        string memory description
    ) internal {
        console.log("Checking Aera Vault V2 Integrity");

        AeraVaultV2 vault = AeraVaultV2(deployedAeraVault);

        assertEq(address(vault.assetRegistry()), address(assetRegistry));
        assertEq(vault.guardian(), guardian);
        assertEq(vault.feeRecipient(), feeRecipient);
        assertEq(vault.fee(), fee);
        assertEq(vault.description(), description);

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
