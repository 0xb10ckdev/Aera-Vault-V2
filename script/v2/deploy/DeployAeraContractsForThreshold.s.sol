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
import "@openzeppelin/IERC4626.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {
    TargetSighash,
    TargetSighashData,
    AssetRegistryParameters,
    HooksParameters,
    VaultParameters
} from "src/v2/Types.sol";
import {DeployScriptBase} from "script/utils/DeployScriptBase.sol";
import "@chainlink/interfaces/AggregatorV2V3Interface.sol";
import "periphery/ICurveFiPool.sol";

contract DeployAeraContracts is DeployScriptBase {
    using stdJson for string;

    TargetSighashData[] targetSighashAllowlist;
    address wethPolygon = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address usdcPolygon  = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address waPolWETH = 0x5e5057b8D220eb8573Bc342136FdF1d869316D18;
    address wstethPolygon  = 0x03b54A6e9a984069379fae1a4fC4dBAE93B3bCCD;
    address swapRouterAddressPolygon  = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    address teth = 0x752eBeb79963cf0732E9c0fec72a49FD1DEfAEAC;
    address T = 0xCdF7028ceAB81fA0C6971208e83fa7872994beE5;
    address weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address usdcOracle = 0x986b5E1e1755e3C2440e960477f25201B0a8bbD4;
    address wsteth = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address waUSDC = 0x2F79D4CEB79EBD26161e51ca0C9300F970DEd54d;
    address uniswapSwapRouter = 0xE592427A0AEce92De3Edee1F18E0157C05861564;

    address[] whitelistedCurveTargets;
    address[] internal whitelistedCurveTargetsMainnet = [
        teth
    ];
    address[] whitelistedERC20Targets;
    address[] internal whitelistedERC20TargetsMainnet = [
        wsteth,
        weth,
        usdc
    ];
    address[] whitelistedERC4626Targets;
    address[] internal whitelistedERC4626TargetsMainnet = [
        waUSDC
    ];
    address[] whitelistedSwapRouters;
    address[] internal whitelistedSwapRoutersMainnet = [
        uniswapSwapRouter
    ];

    /// @notice Deploy AssetRegistry, AeraVaultV2 and Hooks if they were not
    ///         deployed yet.
    /// @dev It uses 0x00 for salt input value.
    /// @return deployedVault The address of deployed AeraVaultV2.
    /// @return deployedAssetRegistry The address of deployed AssetRegistry.
    /// @return deployedHooks The address of deployed Hooks.
    function run()
        public
        returns (
            address deployedVault,
            address deployedAssetRegistry,
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

        if (this.getChainID() == 137) {
            // TODO - add polygon addresses
            //whitelistedCurveTargets = whitelistedCurveTargetsPolygon;
            //whitelistedERC20Targets = whitelistedERC20TargetsPolygon;
            //whitelistedERC4626Targets = whitelistedERC4626TargetsPolygon;
            //whitelistedSwapRouters = whitelistedSwapRoutersPolygon;
        } else if (this.getChainID() == 1) {
            whitelistedCurveTargets = whitelistedCurveTargetsMainnet;
            whitelistedERC20Targets = whitelistedERC20TargetsMainnet;
            whitelistedERC4626Targets = whitelistedERC4626TargetsMainnet;
            whitelistedSwapRouters = whitelistedSwapRoutersMainnet;
        } else {
            revert("unsupported chain");
        }
        for (uint256 i = 0; i < whitelistedCurveTargets.length; i++) {
            targetSighashAllowlist.push(TargetSighashData({
                target: whitelistedCurveTargetsMainnet[i],
                selector: ICurveFiPool.exchange.selector
            }));
        }
        for (uint256 i = 0; i < whitelistedERC20Targets.length; i++) {
            targetSighashAllowlist.push(TargetSighashData({
                target: whitelistedERC20Targets[i],
                selector: IERC20.approve.selector
            }));
        }
        for (uint256 i = 0; i < whitelistedERC4626Targets.length; i++) {
            targetSighashAllowlist.push(TargetSighashData({
                target: whitelistedERC4626Targets[i],
                selector: IERC20.approve.selector
            }));
            targetSighashAllowlist.push(TargetSighashData({
                target: whitelistedERC4626Targets[i],
                selector: IERC4626.deposit.selector
            }));
            targetSighashAllowlist.push(TargetSighashData({
                target: whitelistedERC4626Targets[i],
                selector: IERC4626.withdraw.selector
            }));
            targetSighashAllowlist.push(TargetSighashData({
                target: whitelistedERC4626Targets[i],
                selector: IERC4626.mint.selector
            }));
            targetSighashAllowlist.push(TargetSighashData({
                target: whitelistedERC4626Targets[i],
                selector: IERC4626.redeem.selector
            }));
        }
        for (uint256 i = 0; i < whitelistedSwapRouters.length; i++) {
            targetSighashAllowlist.push(TargetSighashData({
                target: whitelistedSwapRouters[i],
                selector: ISwapRouter.exactInput.selector
            }));
            targetSighashAllowlist.push(TargetSighashData({
                target: whitelistedSwapRouters[i],
                selector: ISwapRouter.exactInputSingle.selector
            }));
            targetSighashAllowlist.push(TargetSighashData({
                target: whitelistedSwapRouters[i],
                selector: ISwapRouter.exactOutput.selector
            }));
            targetSighashAllowlist.push(TargetSighashData({
                target: whitelistedSwapRouters[i],
                selector: ISwapRouter.exactOutputSingle.selector
            }));
        }
        TargetSighashData[] memory targetSighashAllowlistMem =
            new TargetSighashData[](targetSighashAllowlist.length);
        for (uint256 i = 0; i < targetSighashAllowlist.length; i++) {
            targetSighashAllowlistMem[i] = targetSighashAllowlist[i];
        }

        return HooksParameters(
            factory,
            owner == address(0) ? _deployerAddress : owner,
            minDailyValue,
            targetSighashAllowlistMem
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
    function getChainID() external view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }

}
