// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {console} from "forge-std/console.sol";
import {stdJson} from "forge-std/Script.sol";
import {IERC20} from "@openzeppelin/IERC20.sol";
import {AeraVaultAssetRegistry} from "src/v2/AeraVaultAssetRegistry.sol";
import {AeraVaultHooks} from "src/v2/AeraVaultHooks.sol";
import {AeraVaultV2} from "src/v2/AeraVaultV2.sol";
import {AeraVaultV2Factory} from "src/v2/AeraVaultV2Factory.sol";
import {IAssetRegistry} from "src/v2/interfaces/IAssetRegistry.sol";
import {
    TargetSighash,
    TargetSighashData
    AssetRegistryParameters,
    HooksParameters,
    VaultParameters
} from "src/v2/Types.sol";
import {DeployScriptBase} from "script/utils/DeployScriptBase.sol";

contract DeployAeraContracts is DeployScriptBase {
    using stdJson for string;

    /// @notice Deploy AssetRegistry, AeraVaultV2 and Hooks if they were not
    ///         deployed yet.
    /// @dev It uses 0x00 for salt value.
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

    /// @notice Deploy AssetRegistry, AeraVaultV2 and Hooks with the given salt
    ///         if they were not deployed yet.
    /// @param salt The salt value to create contract.
    /// @return deployedAssetRegistry The address of deployed AssetRegistry.
    /// @return deployedVault The address of deployed AeraVaultV2.
    /// @return deployedHooks The address of deployed Hooks.
    function run(bytes32 salt)
        public
        returns (
            address deployedAssetRegistry,
            address deployedVault,
            address deployedHooks
        )
    {
        return runFromSpecifiedConfigPaths(
            salt,
            "/config/AeraVaultAssetRegistry.json",
            "/config/AeraVaultV2.json",
            "/config/AeraVaultHooks.json",
            true
        );
    }

    function runFromSpecifiedConfigPaths(
        bytes32 salt,
        string memory assetRegistryPath,
        string memory aeraVaultV2Path,
        string memory aeraVaultHooksPath,
        bool broadcast
    )
        public
        returns (
            address deployedAssetRegistry,
            address deployedVault,
            address deployedHooks
        )
    {
        if (_deployerAddress == address(0)) {
            _deployerAddress = msg.sender;
        }

        if (broadcast) {
            vm.startBroadcast(_deployerAddress);
        }

        // Get parameters for AssetRegistry
        AssetRegistryParameters memory assetRegistryParameters =
            _getAssetRegistryParams(assetRegistryPath);

        // Get parameters for AeraVaultV2
        (address aeraVaultV2Factory, VaultParameters memory vaultParameters) =
            _getAeraVaultV2Params(aeraVaultV2Path);

        // Get parameters for AeraVaultHooks
        HooksParameters memory hooksParameters =
            _getAeraVaultHooksParams(aeraVaultHooksPath);

        deployedVault =
            AeraVaultV2Factory(aeraVaultV2Factory).computeVaultAddress(salt);

        // Deploy AeraVaultV2, AeraVaultAssetRegistry, AeraVaultHooks
        (deployedVault, deployedAssetRegistry, deployedHooks) =
        AeraVaultV2Factory(aeraVaultV2Factory).create(
            salt,
            vaultParameters.owner,
            vaultParameters.guardian,
            vaultParameters.feeRecipient,
            vaultParameters.fee,
            vaultParameters.description,
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
        _storeDeployedAddress("custody", deployedVault);
        _storeDeployedAddress("assetRegistry", deployedAssetRegistry);
        _storeDeployedAddress("hooks", deployedHooks);

        if (broadcast) {
            vm.stopBroadcast();
        }
    }

    function _getAssetRegistryParams(string memory relFilePath)
        internal
        returns (AssetRegistryParameters memory)
    {
        string memory path = string.concat(vm.projectRoot(), relFilePath);
        string memory json = vm.readFile(path);

        bytes memory rawAssets = json.parseRaw(".assets");

        address owner = json.readAddress(".owner");
        IAssetRegistry.AssetInformation[] memory assets =
            abi.decode(rawAssets, (IAssetRegistry.AssetInformation[]));
        uint256 numeraireId = json.readUint(".numeraireId");
        address feeToken = json.readAddress(".feeToken");

        return AssetRegistryParameters(
            owner == address(0) ? _deployerAddress : owner,
            assets,
            numeraireId,
            IERC20(feeToken)
        );
    }

    function _getAeraVaultV2Params(string memory relFilePath)
        internal
        returns (
            address aeraVaultV2Factory,
            VaultParameters memory vaultParameters
        )
    {
        string memory path = string.concat(vm.projectRoot(), relFilePath);
        string memory json = vm.readFile(path);

        aeraVaultV2Factory = json.readAddress(".aeraVaultV2Factory");
        address owner = json.readAddress(".owner");
        address guardian = json.readAddress(".guardian");
        address feeRecipient = json.readAddress(".feeRecipient");
        uint256 fee = json.readUint(".fee");
        string memory description = json.readString(".description");

        vaultParameters = VaultParameters(
            owner == address(0) ? _deployerAddress : owner,
            address(0),
            address(0),
            guardian,
            feeRecipient,
            fee,
            description
        );
    }

    function _getAeraVaultHooksParams(string memory relFilePath)
        internal
        returns (HooksParameters memory)
    {
        string memory path = string.concat(vm.projectRoot(), relFilePath);
        string memory json = vm.readFile(path);

        address owner = json.readAddress(".owner");
        uint256 maxDailyExecutionLoss = json.readUint(".maxDailyExecutionLoss");
        TargetSighash[] memory targetSighashAllowlist;

        bytes32[] memory allowlistRaw =
            json.readBytes32Array(".targetSighashAllowlist");
        TargetSighash[] memory allowlist;
        assembly {
            allowlist := allowlistRaw
        }
        
        TargetSighashData[] memory targetSighashAllowlist;
        for (uint256 i = 0; i < allowlist.length; i++) {
            targetSighashAllowlist[i] =
                TargetSighashData({
                    target: _getTarget(allowlist[i]),
                    selector: _getSelector(allowlist[i])
                });
        }

        return HooksParameters(
            owner == address(0) ? _deployerAddress : owner,
            maxDailyExecutionLoss,
            targetSighashAllowlist
        );
    }

    function _getTarget(TargetSighash targetSighash) internal pure returns (address) {
        bytes32 ts;
        assembly {
            ts := targetSighash
        }
        return address(bytes20(ts));
    }

    function _getSelector(TargetSighash targetSighash) internal pure returns (bytes4) {
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
            assetRegistry.numeraireId(), assetRegistryParameters.numeraireId
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

        assertEq(address(hooks.custody()), custody);
        assertEq(
            hooks.maxDailyExecutionLoss(),
            hooksParameters.maxDailyExecutionLoss
        );
        assertEq(hooks.currentDay(), block.timestamp / 1 days);
        assertEq(hooks.cumulativeDailyMultiplier(), 1e18);

        uint256 numTargetSighashAllowlist =
            hooksParameters.targetSighashAllowlist.length;

        for (uint256 i = 0; i < numTargetSighashAllowlist; i++) {
            assertTrue(
                hooks.targetSighashAllowed(
                    hooksParameters.targetSighashAllowlist[i]
                )
            );
        }

        console.log("Checked Hooks Integrity");
    }
}
