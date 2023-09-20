// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {Operation, AssetValue} from "src/v2/Types.sol";
import {DeployAeraContractsForThreshold} from "script/v2/deploy/DeployAeraContractsForThreshold.s.sol";
import "src/v2/AeraV2Factory.sol";
import "src/v2/AeraVaultModulesFactory.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/interfaces/IAssetRegistry.sol";
import "src/v2/interfaces/IVault.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/IERC20.sol";
import "forge-std/console.sol";
import {Ops} from "./Ops.sol";

contract TestGuardianForThreshold is Test, DeployAeraContractsForThreshold {
    address internal vaultAddress;
    address internal hooksAddress;
    address internal assetRegistryAddress;
    address internal wrappedNativeToken;
    AeraVaultV2 internal vault;
    uint256 minBlockNumberPolygon = 46145721;
    uint256 minBlockNumberMainnet = 18171594;

    modifier whenPolygon() {
        if (block.chainid != 137) {
            return;
        }
        if (block.number < minBlockNumberPolygon) {
            return;
        }
        _;
    }

    modifier whenMainnet() {
        if (block.chainid != 1) {
            return;
        }
        if (block.number < minBlockNumberPolygon) {
            return;
        }
        _;
    }

    function setUp() public virtual {
        _deployerAddress = address(this);
        vm.label(wethPolygon, "wethPolygon");
        vm.label(waPolWETH, "waPolWETH");
        vm.label(usdcPolygon, "usdcPolygon");
        vm.label(weth, "wethMainnet");
        vm.label(waPolUSDC, "waPolUSDC");
        vm.label(usdc, "usdcMainnet");
        if (block.chainid == 137) {
            wrappedNativeToken = wmaticPolygon;
        } else {
            wrappedNativeToken = weth;
        }

        _deployFactory();
        _deployContracts();
    }

    function test_submitSwapAndDepositPolygon() public whenPolygon {
        assertEq(address(this), vault.owner());

        AssetValue[] memory amounts = new AssetValue[](2);
        amounts[0] = AssetValue({asset: IERC20(usdcPolygon), value: 50e6});
        amounts[1] = AssetValue({asset: IERC20(wethPolygon), value: 1e18});

        deal(usdcPolygon, address(this), amounts[0].value);
        deal(wethPolygon, address(this), amounts[1].value);
        IERC20(usdcPolygon).approve(vaultAddress, amounts[0].value);
        IERC20(wethPolygon).approve(vaultAddress, amounts[1].value);
        vault.deposit(amounts);
        vault.resume();

        // TODO: test warping, fees, etc
        vm.startPrank(vault.guardian());
        // fails with over/underflow if this is uncommented, in wapolweth::convertToAssets
        // vm.warp(1000);
        Operation[] memory operations = _loadSwapAndDepositOperationsPolygon();
        vault.submit(operations);
        // fails with no fees available when no vm.warp
        vm.expectRevert(
            abi.encodePacked(
                IVault.Aera__NoClaimableFeesForCaller.selector,
                abi.encode(vault.guardian())
            )
        );
        vault.claim();
        vm.stopPrank();
    }

    function test_submitSwapAndDepositMainnet() public whenMainnet {
        assertEq(address(this), vault.owner());

        AssetValue[] memory amounts = new AssetValue[](2);
        amounts[0] = AssetValue({asset: IERC20(usdc), value: 50e6});
        amounts[1] = AssetValue({asset: IERC20(weth), value: 1e18});

        deal(usdc, address(this), amounts[0].value);
        deal(weth, address(this), amounts[1].value);
        IERC20(usdc).approve(vaultAddress, amounts[0].value);
        IERC20(weth).approve(vaultAddress, amounts[1].value);
        vault.deposit(amounts);
        vault.resume();

        // TODO: test warping, fees, etc
        vm.startPrank(vault.guardian());
        // fails with over/underflow if this is uncommented, in wapolweth::convertToAssets
        // vm.warp(1000);

        Operation[] memory operations = _loadSwapAndDepositOperationsMainnet();

        vault.submit(operations);
        // fails with no fees available when no vm.warp
        vm.expectRevert(
            abi.encodePacked(
                IVault.Aera__NoClaimableFeesForCaller.selector,
                abi.encode(vault.guardian())
            )
        );
        vault.claim();
        vm.stopPrank();
    }
    
    function test_curveSwap() public whenMainnet {
        uint256 startSize = 15_000_000e18;
        uint256 tradeSize = 252737989387656459408879;
        uint256 minReceived = 2727915407161190281;

        AssetValue[] memory amounts = new AssetValue[](1);
        uint256 i = 0;
        amounts[i++] = AssetValue({asset: IERC20(T), value: startSize});
        assert(amounts.length == i);

        for (i = 0; i < amounts.length; i++) {
            console.log(
                "Approving %s",
                IERC20Metadata(address(amounts[i].asset)).symbol()
            );
            deal(address(amounts[i].asset), address(this), amounts[i].value);
            amounts[i].asset.approve(address(vault), amounts[i].value);
        }
        vault.deposit(amounts);
        vault.resume();

        Operation[] memory operations = new Operation[](2);

        i = 0;
        operations[i++] = Ops.approve(T, teth, tradeSize);
        operations[i++] = Ops.curveSwap(teth, T, weth, tradeSize, minReceived);
        assert(operations.length == i);

        assert(IERC20(T).balanceOf(address(vault)) == startSize);
        assert(IERC20(weth).balanceOf(address(vault)) == 0);

        vm.startPrank(vault.guardian());
        vault.submit(operations);
        vm.stopPrank();

        assert(IERC20(T).balanceOf(address(vault)) == startSize - tradeSize);
        assert(IERC20(weth).balanceOf(address(vault)) >= minReceived);
    }

    function _deployFactory() internal {
        AeraV2Factory factory = new AeraV2Factory(wrappedNativeToken);
        v2Factory = address(factory);
        AeraVaultModulesFactory modulesFactory = new AeraVaultModulesFactory(v2Factory);
        vaultModulesFactory = address(modulesFactory);
        vm.label(v2Factory, "Factory");
        vm.label(vaultModulesFactory, "ModulesFactory");
    }

    function _deployContracts() internal {
        _deployerAddress = address(this);

        (vaultAddress, assetRegistryAddress, hooksAddress) = run();
        vm.label(vaultAddress, "VAULT");
        vm.label(hooksAddress, "HOOKS");
        vm.label(assetRegistryAddress, "ASSET_REGISTRY");
        vault = AeraVaultV2(payable(vaultAddress));
    }

    function _loadSwapAndDepositOperationsPolygon() internal view returns (Operation[] memory) {
        Operation[] memory operations = new Operation[](4);

        uint256 i = 0;
        uint256 exactInput =  2480252;
        uint256 minOutput = 1293364631244994;
        operations[i++] = Ops.approve(usdcPolygon, uniswapSwapRouter, exactInput);
        operations[i++] = Ops.swap(
            uniswapSwapRouter, 
            ISwapRouter.ExactInputParams(
                abi.encodePacked(usdcPolygon, uint24(500), wethPolygon),
                address(this),
                block.timestamp + 3600,
                exactInput,
                minOutput
            )
        );

        operations[i++] = Ops.approve(wethPolygon, waPolWETH, minOutput);
        operations[i++] = Ops.deposit(waPolWETH, minOutput, vaultAddress);
        return operations;
    }

    function _loadSwapAndDepositOperationsMainnet() internal view returns (Operation[] memory) {
        uint256 exactInput =  2480252;
        uint256 minOutput = 1293364631244994;
        Operation[] memory operations = new Operation[](4);

        uint256 i = 0;
        operations[i++] = Ops.approve(usdc, uniswapSwapRouter, exactInput);
        operations[i++] = Ops.swap(
            uniswapSwapRouter, 
            ISwapRouter.ExactInputParams(
                abi.encodePacked(usdc, uint24(500), weth),
                address(this),
                block.timestamp + 3600,
                exactInput,
                minOutput
            )
        );
        uint256 depositAmount = 20e6;
        operations[i++] = Ops.approve(usdc, waUSDC, depositAmount);
        operations[i++] = Ops.deposit(waUSDC, depositAmount, vaultAddress);
        assert(operations.length == i);
        return operations;
    }

    function _getAssetRegistryParams(string memory) internal override returns (AssetRegistryParameters memory) {
        IAssetRegistry.AssetInformation[] memory assets;
        address numeraireToken;
        address feeToken;
        if (block.chainid == 137) {
            numeraireToken = wethPolygon;
            feeToken = wethPolygon;
            assets = _getAssetsPolygon();
        } else {
            numeraireToken = weth;
            feeToken = weth;
            assets = _getAssets();
        }

        return AssetRegistryParameters(
            vaultModulesFactory,
            address(this),
            assets,
            IERC20(numeraireToken),
            IERC20(feeToken),
            AggregatorV2V3Interface(address(0))
        );
    }

    function _getAssetsPolygon() internal returns (IAssetRegistry.AssetInformation[] memory) {
        IAssetRegistry.AssetInformation[] memory assets = new IAssetRegistry.AssetInformation[](6);
        uint256 i = 0;
        assets[i++] = IAssetRegistry.AssetInformation({
            asset: IERC20(wethPolygon),
            heartbeat: 86400,
            isERC4626: false,
            oracle: AggregatorV2V3Interface(address(0))
        });
        assets[i++] = IAssetRegistry.AssetInformation({
            asset: IERC20(usdcPolygon),
            heartbeat: 86400,
            isERC4626: false,
            oracle: AggregatorV2V3Interface(usdcOraclePolygon)
        });
        assets[i++] = IAssetRegistry.AssetInformation({
            asset: IERC20(wstethPolygon),
            heartbeat: 86400,
            isERC4626: false,
            oracle: AggregatorV2V3Interface(wstethOraclePolygon)
        });
        assets[i++] = IAssetRegistry.AssetInformation({
            asset: IERC20(wmaticPolygon),
            heartbeat: 86400,
            isERC4626: false,
            oracle: AggregatorV2V3Interface(wmaticOraclePolygon)
        });
        assets[i++] = IAssetRegistry.AssetInformation({
            asset: IERC20(waPolUSDC),
            heartbeat: 86400,
            isERC4626: true,
            oracle: AggregatorV2V3Interface(address(0))
        });
        assets[i++] = IAssetRegistry.AssetInformation({
            asset: IERC20(waPolWETH),
            heartbeat: 86400,
            isERC4626: true,
            oracle: AggregatorV2V3Interface(address(0))
        });

        _sortAssets(assets);
        assertEq(assets.length, i);
        return assets;
    }
}
