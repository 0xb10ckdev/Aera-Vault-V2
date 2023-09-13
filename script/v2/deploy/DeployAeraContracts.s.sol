// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/IERC20.sol";
import {AggregatorV2V3Interface} from
    "@chainlink/interfaces/AggregatorV2V3Interface.sol";
import {AeraVaultAssetRegistry} from "src/v2/AeraVaultAssetRegistry.sol";
import {AeraVaultHooks} from "src/v2/AeraVaultHooks.sol";
import {AeraVaultV2} from "src/v2/AeraVaultV2.sol";
import {AeraV2Factory} from "src/v2/AeraV2Factory.sol";
import {IAssetRegistry} from "src/v2/interfaces/IAssetRegistry.sol";
import {
    TargetSighash,
    TargetSighashData,
    AssetRegistryParameters,
    HooksParameters,
    VaultParameters
} from "src/v2/Types.sol";
import {DeployScriptBase} from "script/utils/DeployScriptBase.sol";
import "@chainlink/interfaces/AggregatorV2V3Interface.sol";

contract DeployAeraContracts is DeployScriptBase {
    using stdJson for string;

    /// @notice Deploy AssetRegistry, AeraVaultV2 and Hooks if they were not
    ///         deployed yet.
    /// @dev It uses 0x00 for salt input value.
    /// @return deployedAssetRegistry The address of deployed AssetRegistry.
    /// @return deployedVault The address of deployed AeraVaultV2.
    /// @return deployedHooks The address of deployed Hooks.
    function run()
        public
        returns (
            address deployedAssetRegistry,
            address deployedVault,
            address deployedHooks
        )
    {
        return run(0);
    }

    /// @notice Deploy AssetRegistry, AeraVaultV2 and Hooks with the given salt input
    ///         if they were not deployed yet.
    /// @param saltInput The salt input value to generate salt.
    /// @return deployedVault The address of deployed AeraVaultV2.
    /// @return deployedAssetRegistry The address of deployed AssetRegistry.
    /// @return deployedHooks The address of deployed Hooks.
    function run(bytes32 saltInput)
        public
        returns (
            address deployedVault,
            address deployedAssetRegistry,
            address deployedHooks
        )
    {
        return runFromSpecifiedConfigPaths(
            saltInput,
            "/config/AeraVaultAssetRegistry.json",
            "/config/AeraVaultV2.json",
            "/config/AeraVaultHooks.json",
            true
        );
    }

    function runFromSpecifiedConfigPaths(
        bytes32 saltInput,
        string memory assetRegistryPath,
        string memory aeraVaultV2Path,
        string memory aeraVaultHooksPath,
        bool broadcast
    )
        public
        returns (
            address deployedVault,
            address deployedAssetRegistry,
            address deployedHooks
        )
    {
        if (_deployerAddress == address(0)) {
            _deployerAddress = msg.sender;
        }

        if (broadcast) {
            vm.startBroadcast(_deployerAddress);
        }

        // Get parameters for AeraVaultV2
        (
            address v2Factory,
            VaultParameters memory vaultParameters,
            string memory description
        ) = _getAeraVaultV2Params(aeraVaultV2Path);

        // Get parameters for AssetRegistry
        AssetRegistryParameters memory assetRegistryParameters =
            _getAssetRegistryParams(assetRegistryPath);

        // Get parameters for AeraVaultHooks
        HooksParameters memory hooksParameters =
            _getAeraVaultHooksParams(aeraVaultHooksPath);

        // Deploy AeraVaultV2, AeraVaultAssetRegistry, AeraVaultHooks
        (deployedVault, deployedAssetRegistry, deployedHooks) = AeraV2Factory(
            v2Factory
        ).create(
            saltInput,
            description,
            vaultParameters,
            assetRegistryParameters,
            hooksParameters
        );

        // Check deployed AeraVaultV2
        _checkAeraVaultV2Integrity(
            AeraVaultV2(payable(deployedVault)),
            deployedAssetRegistry,
            vaultParameters
        );

        // Check deployed AssetRegistry
        _checkAssetRegistryIntegrity(
            AeraVaultAssetRegistry(deployedAssetRegistry),
            assetRegistryParameters
        );

        // Check deployed AeraVaultHooks
        _checkAeraVaultHooksIntegrity(
            AeraVaultHooks(deployedHooks), deployedVault, hooksParameters
        );

        // Store deployed address
        _storeDeployedAddress("vault", deployedVault);
        _storeDeployedAddress("assetRegistry", deployedAssetRegistry);
        _storeDeployedAddress("hooks", deployedHooks);

        if (broadcast) {
            vm.stopBroadcast();
        }
    }

    function _getAeraVaultV2Params(string memory relFilePath)
        internal
        returns (
            address v2Factory,
            VaultParameters memory vaultParameters,
            string memory description
        )
    {
        string memory path = string.concat(vm.projectRoot(), relFilePath);
        string memory json = vm.readFile(path);

        v2Factory = json.readAddress(".v2Factory");
        if (v2Factory == address(0)) {
            string memory factoryPath = string.concat(
                vm.projectRoot(), "/config/FactoryAddresses.json"
            );
            string memory factoryJson = vm.readFile(factoryPath);
            v2Factory = factoryJson.readAddress(".v2Factory");
        }
        address owner = json.readAddress(".owner");
        address guardian = json.readAddress(".guardian");
        address feeRecipient = json.readAddress(".feeRecipient");
        uint256 fee = json.readUint(".fee");
        description = json.readString(".description");

        vaultParameters = VaultParameters(
            owner == address(0) ? _deployerAddress : owner,
            guardian,
            feeRecipient,
            fee
        );
    }

    function _getAssetRegistryParams(string memory relFilePath)
        internal
        returns (AssetRegistryParameters memory)
    {
        string memory path = string.concat(vm.projectRoot(), relFilePath);
        string memory json = vm.readFile(path);

        bytes memory rawAssets = json.parseRaw(".assets");

        address factory = json.readAddress(".assetRegistryFactory");
        if (factory == address(0)) {
            string memory factoryPath = string.concat(
                vm.projectRoot(), "/config/FactoryAddresses.json"
            );
            string memory factoryJson = vm.readFile(factoryPath);
            factory = factoryJson.readAddress(".vaultModulesFactory");
        }
        address owner = json.readAddress(".owner");
        IAssetRegistry.AssetInformation[] memory assets =
            abi.decode(rawAssets, (IAssetRegistry.AssetInformation[]));
        address numeraireToken = json.readAddress(".numeraireToken");
        address feeToken = json.readAddress(".feeToken");
        address sequencer = json.readAddress(".sequencer");

        return AssetRegistryParameters(
            factory,
            owner == address(0) ? _deployerAddress : owner,
            assets,
            IERC20(numeraireToken),
            IERC20(feeToken),
            AggregatorV2V3Interface(sequencer)
        );
    }

    function _getAeraVaultHooksParams(string memory relFilePath)
        internal
        returns (HooksParameters memory)
    {
        string memory path = string.concat(vm.projectRoot(), relFilePath);
        string memory json = vm.readFile(path);

        address factory = json.readAddress(".hooksFactory");
        if (factory == address(0)) {
            string memory factoryPath = string.concat(
                vm.projectRoot(), "/config/FactoryAddresses.json"
            );
            string memory factoryJson = vm.readFile(factoryPath);
            factory = factoryJson.readAddress(".vaultModulesFactory");
        }
        address owner = json.readAddress(".owner");
        uint256 minDailyValue = json.readUint(".minDailyValue");

        bytes32[] memory allowlistRaw =
            json.readBytes32Array(".targetSighashAllowlist");
        TargetSighash[] memory allowlist;
        assembly {
            allowlist := allowlistRaw
        }

        TargetSighashData[] memory targetSighashAllowlist =
            new TargetSighashData[](allowlist.length);
        for (uint256 i = 0; i < allowlist.length; i++) {
            targetSighashAllowlist[i] = TargetSighashData({
                target: _getTarget(allowlist[i]),
                selector: _getSelector(allowlist[i])
            });
        }

        return HooksParameters(
            factory,
            owner == address(0) ? _deployerAddress : owner,
            minDailyValue,
            targetSighashAllowlist
        );
    }

    function _getTarget(TargetSighash targetSighash)
        internal
        pure
        returns (address)
    {
        bytes32 ts;
        assembly {
            ts := targetSighash
        }
        return address(bytes20(ts));
    }

    function _getSelector(TargetSighash targetSighash)
        internal
        pure
        returns (bytes4)
    {
        bytes32 ts;
        assembly {
            ts := targetSighash
        }
        return bytes4(ts << (20 * 8));
    }

    function _checkAssetRegistryIntegrity(
        AeraVaultAssetRegistry assetRegistry,
        AssetRegistryParameters memory assetRegistryParameters
    ) internal {
        IAssetRegistry.AssetInformation[] memory assets =
            assetRegistryParameters.assets;

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

        assertEq(
            address(assetRegistry.numeraireToken()),
            address(assetRegistryParameters.numeraireToken)
        );
        assertEq(
            address(assetRegistry.feeToken()),
            address(assetRegistryParameters.feeToken)
        );

        console.log("Checked Asset Registry Integrity");
    }

    function _checkAeraVaultV2Integrity(
        AeraVaultV2 vault,
        address assetRegistry,
        VaultParameters memory vaultParameters
    ) internal {
        console.log("Checking Aera Vault V2 Integrity");

        assertEq(address(vault.assetRegistry()), address(assetRegistry));
        assertEq(vault.guardian(), vaultParameters.guardian);
        assertEq(vault.feeRecipient(), vaultParameters.feeRecipient);
        assertEq(vault.fee(), vaultParameters.fee);

        console.log("Checked Aera Vault V2 Integrity");
    }

    function _checkAeraVaultHooksIntegrity(
        AeraVaultHooks hooks,
        address vault,
        HooksParameters memory hooksParameters
    ) internal {
        console.log("Checking Hooks Integrity");

        assertEq(address(hooks.vault()), vault);
        assertEq(hooks.minDailyValue(), hooksParameters.minDailyValue);
        assertEq(hooks.currentDay(), block.timestamp / 1 days);
        assertEq(hooks.cumulativeDailyMultiplier(), 1e18);

        uint256 numTargetSighashAllowlist =
            hooksParameters.targetSighashAllowlist.length;

        for (uint256 i = 0; i < numTargetSighashAllowlist; i++) {
            assertTrue(
                hooks.targetSighashAllowed(
                    hooksParameters.targetSighashAllowlist[i].target,
                    hooksParameters.targetSighashAllowlist[i].selector
                )
            );
        }

        console.log("Checked Hooks Integrity");
    }
}
