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
import {DeployAeraContracts} from "script/v2/deploy/DeployAeraContracts.s.sol";
import {DeployAeraV2Factory} from "script/v2/deploy/DeployAeraV2Factory.s.sol";
import {DeployAeraVaultModulesFactory} from
    "script/v2/deploy/DeployAeraVaultModulesFactory.s.sol";
import "@chainlink/interfaces/AggregatorV2V3Interface.sol";

contract DeployMeta is DeployScriptBase {
    using stdJson for string;

    function run()
        public
        returns (
            address deployedV2Factory,
            address deployedModulesFactory,
            address deployedVault,
            address deployedAssetRegistry,
            address deployedHooks
        )
    {
        return run(0);
    }

    function run(bytes32 saltInput)
        public
        returns (
            address deployedV2Factory,
            address deployedModulesFactory,
            address deployedVault,
            address deployedAssetRegistry,
            address deployedHooks
        )
    {
        return runFromSpecifiedConfigPaths(
            saltInput,
            "/config/FactoryAddresses.json"
        );
    }

    function runFromSpecifiedConfigPaths(
        bytes32 saltInput,
        string memory factoryAddressesPath
    )
        public
        returns (
            address deployedV2Factory,
            address deployedModulesFactory,
            address deployedVault,
            address deployedAssetRegistry,
            address deployedHooks
        )
    {
        if (_deployerAddress == address(0)) {
            _deployerAddress = msg.sender;
        }

        deployedV2Factory = _deployV2Factory(factoryAddressesPath);
        deployedModulesFactory = _deployVaultModulesFactory(deployedV2Factory, factoryAddressesPath);

        (deployedVault, deployedAssetRegistry, deployedHooks) = _deployAeraContracts(saltInput);
    }

    function _deployAeraContracts(bytes32 saltInput) 
        internal 
        returns (
            address deployedVault, 
            address deployedAssetRegistry, 
            address deployedHooks
        )
    {
        DeployAeraContracts deployAeraContracts = new
            DeployAeraContracts();
        deployAeraContracts.setDeployerAddress(_deployerAddress);
        (deployedVault, deployedAssetRegistry, deployedHooks) =
            deployAeraContracts.run(saltInput);
    }

    function _deployVaultModulesFactory(address deployedV2Factory, string memory factoryAddressesPath) 
        internal 
        returns (address deployedModulesFactory)
    {
        DeployAeraVaultModulesFactory deployAeraVaultModulesFactory = new
            DeployAeraVaultModulesFactory();
        deployAeraVaultModulesFactory.setDeployerAddress(_deployerAddress);
        deployedModulesFactory = address(deployAeraVaultModulesFactory.run());
        vm.serializeAddress(
            "FactoryAddresses", "vaultModulesFactory", deployedModulesFactory
        );
        string memory path =
            string.concat(vm.projectRoot(), factoryAddressesPath);
        vm.writeJson(
            vm.serializeAddress(
                "FactoryAddresses", "v2Factory", deployedV2Factory
            ),
            path
        );
    }
    function _deployV2Factory(string memory factoryAddressesPath) 
        internal 
        returns (address deployedV2Factory) 
    {
            DeployAeraV2Factory deployAeraV2Factory = new DeployAeraV2Factory();
            deployAeraV2Factory.setDeployerAddress(_deployerAddress);
            deployedV2Factory = address(deployAeraV2Factory.run());
            string memory path =
                string.concat(vm.projectRoot(), factoryAddressesPath);
            vm.writeJson(
                vm.serializeAddress(
                    "FactoryAddresses", "v2Factory", deployedV2Factory
                ),
                path
            );
        }
}
