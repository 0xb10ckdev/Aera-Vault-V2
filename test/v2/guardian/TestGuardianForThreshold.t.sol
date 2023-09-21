// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {Operation, AssetValue} from "src/v2/Types.sol";
import {DeployAeraContractsForThreshold} from
    "script/v2/deploy/DeployAeraContractsForThreshold.s.sol";
import "src/v2/AeraV2Factory.sol";
import "src/v2/AeraVaultModulesFactory.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/AeraVaultHooks.sol";
import "src/v2/interfaces/IAssetRegistry.sol";
import "src/v2/interfaces/IVault.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/IERC20.sol";
import "forge-std/console.sol";
import {Ops} from "./Ops.sol";
import "periphery/interfaces/IAeraV2Oracle.sol";

contract TestGuardianForThreshold is Test, DeployAeraContractsForThreshold {
    address public vaultAddress;
    address public hooksAddress;
    address public assetRegistryAddress;
    address public wrappedNativeToken;
    AeraVaultV2 public vault;
    // forge test --fork-url $POLYGON_RPC_URL --fork-block-number 47786597
    uint256 public requiredBlockNumberPolygon = 47786597;
    // forge test --fork-url $ETHEREUM_RPC_URL --fork-block-number 18186365
    uint256 public requiredBlockNumberMainnet = 18186365;

    error WrongBlockNumber(uint256 expected, uint256 actual);

    modifier whenPolygon() {
        if (block.chainid != 137) {
            return;
        }
        if (block.number != requiredBlockNumberPolygon) {
            revert WrongBlockNumber({
                expected: requiredBlockNumberPolygon,
                actual: block.number
            });
        }
        _;
    }

    modifier whenMainnet() {
        if (block.chainid != 1) {
            return;
        }
        if (block.number != requiredBlockNumberMainnet) {
            revert WrongBlockNumber({
                expected: requiredBlockNumberMainnet,
                actual: block.number
            });
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
        if (block.chainid == 137 || block.chainid == 1) {
            if (block.chainid == 137) {
                wrappedNativeToken = wmaticPolygon;
            } else {
                wrappedNativeToken = weth;
            }

            _deployFactory();
            _deployContracts();
        }
    }

    function _depositAmounts(AssetValue[] memory amounts) internal {
        for (uint256 i = 0; i < amounts.length; i++) {
            deal(address(amounts[i].asset), address(this), amounts[i].value);
            amounts[i].asset.approve(address(vault), amounts[i].value);
        }
        vault.deposit(amounts);
        vault.resume();
    }

    function test_submitSwapAndDepositPolygonExactInput() public whenPolygon {
        assertEq(address(this), vault.owner());

        AssetValue[] memory amounts = new AssetValue[](2);
        amounts[0] = AssetValue({asset: IERC20(usdcPolygon), value: 50e6});
        amounts[1] = AssetValue({asset: IERC20(wethPolygon), value: 1e18});
        _depositAmounts(amounts);

        // TODO: test warping, fees, etc
        vm.startPrank(vault.guardian());
        // fails with over/underflow if this is uncommented, in wapolweth::convertToAssets
        // vm.warp(1000);
        Operation[] memory operations = _loadSwapAndDepositOperationsPolygonExactInput();
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

    function test_submitSwapAndDepositPolygonExactOutput() public whenPolygon {
        assertEq(address(this), vault.owner());

        AssetValue[] memory amounts = new AssetValue[](2);
        amounts[0] = AssetValue({asset: IERC20(usdcPolygon), value: 50e6});
        amounts[1] = AssetValue({asset: IERC20(wethPolygon), value: 1e18});
        _depositAmounts(amounts);

        // TODO: test warping, fees, etc
        vm.startPrank(vault.guardian());
        // fails with over/underflow if this is uncommented, in wapolweth::convertToAssets
        // vm.warp(1000);
        Operation[] memory operations = _loadSwapAndDepositOperationsPolygonExactOutput();
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

    function test_submitSwapAndDepositMainnetExactInput() public whenMainnet {
        assertEq(address(this), vault.owner());

        AssetValue[] memory amounts = new AssetValue[](2);
        amounts[0] = AssetValue({asset: IERC20(usdc), value: 50e6});
        amounts[1] = AssetValue({asset: IERC20(weth), value: 1e18});
        _depositAmounts(amounts);

        // TODO: test warping, fees, etc
        vm.startPrank(vault.guardian());
        // fails with over/underflow if this is uncommented, in wapolweth::convertToAssets
        // vm.warp(1000);

        Operation[] memory operations = _loadSwapAndDepositOperationsMainnetExactInput();

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

    function test_submitSwapAndDepositMainnetExactOutput() public whenMainnet {
        assertEq(address(this), vault.owner());

        AssetValue[] memory amounts = new AssetValue[](2);
        amounts[0] = AssetValue({asset: IERC20(usdc), value: 50e6});
        amounts[1] = AssetValue({asset: IERC20(weth), value: 1e18});
        _depositAmounts(amounts);

        // TODO: test warping, fees, etc
        vm.startPrank(vault.guardian());
        // fails with over/underflow if this is uncommented, in wapolweth::convertToAssets
        // vm.warp(1000);

        Operation[] memory operations = _loadSwapAndDepositOperationsMainnetExactOutput();

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
        _depositAmounts(amounts);

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

    function test_withdrawWAUSDC() public whenMainnet {
        uint256 startSize = 50e6;
        uint256 withdrawAmt = IERC4626(waUSDC).convertToShares(startSize) / 2;

        AssetValue[] memory amounts = new AssetValue[](1);
        uint256 i = 0;
        amounts[i++] = AssetValue({asset: IERC20(usdc), value: startSize});
        assert(amounts.length == i);
        _depositAmounts(amounts);

        Operation[] memory operations = new Operation[](3);

        i = 0;

        operations[i++] = Ops.approve(usdc, waUSDC, startSize);
        operations[i++] = Ops.deposit(waUSDC, startSize, address(vault));
        operations[i++] = Ops.withdraw(waUSDC, withdrawAmt, address(vault));

        assert(operations.length == i);

        assert(IERC20(waUSDC).balanceOf(address(vault)) == 0);
        assert(IERC20(usdc).balanceOf(address(vault)) == startSize);

        vm.startPrank(vault.guardian());
        vault.submit(operations);
        vm.stopPrank();

        uint256 startSizeWaUSDC = IERC4626(waUSDC).convertToShares(startSize);
        uint256 usdcEndAmt = IERC4626(waUSDC).convertToAssets(withdrawAmt);
        assert(
            IERC20(waUSDC).balanceOf(address(vault))
                >= startSizeWaUSDC - withdrawAmt
        );
        assert(
            IERC20(waUSDC).balanceOf(address(vault))
                < startSizeWaUSDC - withdrawAmt + 16e3
        ); // small wiggle room
        uint256 actualUSDCEndAmt = IERC20(usdc).balanceOf(address(vault));
        assert(usdcEndAmt - actualUSDCEndAmt < 16e3); // small wiggle room
    }

    function test_swapWETHUSDCExactInput() public whenMainnet {
        uint256 exactInput = 1e18;
        uint256 minOutput = 1587e6;

        AssetValue[] memory amounts = new AssetValue[](1);
        uint256 i = 0;
        amounts[i++] = AssetValue({asset: IERC20(weth), value: exactInput});
        assert(amounts.length == i);
        _depositAmounts(amounts);

        Operation[] memory operations = new Operation[](2);

        i = 0;
        operations[i++] = Ops.approve(weth, uniswapSwapRouter, exactInput);
        operations[i++] = Ops.swapExactInput(
            uniswapSwapRouter,
            ISwapRouter.ExactInputParams(
                abi.encodePacked(weth, uint24(500), usdc),
                address(vault),
                block.timestamp + 3600,
                exactInput,
                minOutput
            )
        );
        assert(operations.length == i);

        assert(IERC20(weth).balanceOf(address(vault)) == exactInput);
        assert(IERC20(usdc).balanceOf(address(vault)) == 0);

        vm.startPrank(vault.guardian());
        vault.submit(operations);
        vm.stopPrank();
        assert(IERC20(weth).balanceOf(address(vault)) == 0);
        assert(IERC20(usdc).balanceOf(address(vault)) >= minOutput);
    }

    function test_swapWETHUSDCExactOutput() public whenMainnet {
        uint256 maxInput = 1e18;
        uint256 exactOutput = 1587e6;

        AssetValue[] memory amounts = new AssetValue[](1);
        uint256 i = 0;
        amounts[i++] = AssetValue({asset: IERC20(weth), value: maxInput});
        assert(amounts.length == i);
        _depositAmounts(amounts);

        Operation[] memory operations = new Operation[](3);

        i = 0;
        operations[i++] = Ops.approve(weth, uniswapSwapRouter, maxInput);
        operations[i++] = Ops.swapExactOutput(
            uniswapSwapRouter,
            ISwapRouter.ExactOutputParams(
                abi.encodePacked(usdc, uint24(500), weth),
                address(vault),
                block.timestamp + 3600,
                exactOutput,
                maxInput
            )
        );
        operations[i++] = Ops.approve(weth, uniswapSwapRouter, 0);
        assert(operations.length == i);

        assert(IERC20(weth).balanceOf(address(vault)) == maxInput);
        assert(IERC20(usdc).balanceOf(address(vault)) == 0);

        vm.startPrank(vault.guardian());
        vault.submit(operations);
        vm.stopPrank();
        assert(IERC20(weth).balanceOf(address(vault)) < maxInput);
        assert(IERC20(usdc).balanceOf(address(vault)) == exactOutput);
    }

    function test_swapWstETHETHExactInput() public whenMainnet {
        uint256 exactInput = 1e18;
        uint256 minOutput = 1.12e18;

        AssetValue[] memory amounts = new AssetValue[](1);
        uint256 i = 0;
        amounts[i++] = AssetValue({asset: IERC20(wsteth), value: exactInput});
        assert(amounts.length == i);
        _depositAmounts(amounts);

        Operation[] memory operations = new Operation[](2);

        i = 0;
        operations[i++] = Ops.approve(wsteth, uniswapSwapRouter, exactInput);
        operations[i++] = Ops.swapExactInput(
            uniswapSwapRouter,
            ISwapRouter.ExactInputParams(
                abi.encodePacked(wsteth, uint24(100), weth),
                address(vault),
                block.timestamp + 1 hours,
                exactInput,
                minOutput
            )
        );
        assert(operations.length == i);

        assert(IERC20(wsteth).balanceOf(address(vault)) == exactInput);
        assert(IERC20(weth).balanceOf(address(vault)) == 0);

        vm.startPrank(vault.guardian());
        vault.submit(operations);
        vm.stopPrank();
        assert(IERC20(wsteth).balanceOf(address(vault)) == 0);
        assert(IERC20(weth).balanceOf(address(vault)) >= minOutput);
    }

    function test_swapWstETHETHExactOutput() public whenMainnet {
        uint256 maxInput = 1e18;
        uint256 exactOutput = 1.12e18;

        AssetValue[] memory amounts = new AssetValue[](1);
        uint256 i = 0;
        amounts[i++] = AssetValue({asset: IERC20(wsteth), value: maxInput});
        assert(amounts.length == i);
        _depositAmounts(amounts);

        Operation[] memory operations = new Operation[](3);

        i = 0;
        operations[i++] = Ops.approve(wsteth, uniswapSwapRouter, maxInput);
        operations[i++] = Ops.swapExactOutput(
            uniswapSwapRouter,
            ISwapRouter.ExactOutputParams(
                abi.encodePacked(weth, uint24(100), wsteth),
                address(vault),
                block.timestamp + 1 hours,
                exactOutput,
                maxInput
            )
        );
        operations[i++] = Ops.approve(wsteth, uniswapSwapRouter, 0);
        assert(operations.length == i);

        assert(IERC20(wsteth).balanceOf(address(vault)) == maxInput);
        assert(IERC20(weth).balanceOf(address(vault)) == 0);

        vm.startPrank(vault.guardian());
        vault.submit(operations);
        vm.stopPrank();
        assert(IERC20(wsteth).balanceOf(address(vault)) < maxInput);
        assert(IERC20(weth).balanceOf(address(vault)) == exactOutput);
    }

    function test_swapWethWstETHExactInput() public whenMainnet {
        uint256 exactInput = 1.15e18;
        uint256 minOutput = 1e18;

        AssetValue[] memory amounts = new AssetValue[](1);
        uint256 i = 0;
        amounts[i++] = AssetValue({asset: IERC20(weth), value: exactInput});
        assert(amounts.length == i);
        _depositAmounts(amounts);

        Operation[] memory operations = new Operation[](2);

        i = 0;
        operations[i++] = Ops.approve(weth, uniswapSwapRouter, exactInput);
        operations[i++] = Ops.swapExactInput(
            uniswapSwapRouter,
            ISwapRouter.ExactInputParams(
                abi.encodePacked(weth, uint24(100), wsteth),
                address(vault),
                block.timestamp + 1 hours,
                exactInput,
                minOutput
            )
        );
        assert(operations.length == i);

        assert(IERC20(weth).balanceOf(address(vault)) == exactInput);
        assert(IERC20(wsteth).balanceOf(address(vault)) == 0);

        vm.startPrank(vault.guardian());
        vault.submit(operations);
        vm.stopPrank();
        assert(IERC20(weth).balanceOf(address(vault)) == 0);
        assert(IERC20(wsteth).balanceOf(address(vault)) >= minOutput);
    }

    function test_swapWethWstETHExactOutput() public whenMainnet {
        uint256 maxInput = 1.15e18;
        uint256 exactOutput = 1e18;

        AssetValue[] memory amounts = new AssetValue[](1);
        uint256 i = 0;
        amounts[i++] = AssetValue({asset: IERC20(weth), value: maxInput});
        assert(amounts.length == i);
        _depositAmounts(amounts);

        Operation[] memory operations = new Operation[](3);

        i = 0;
        operations[i++] = Ops.approve(weth, uniswapSwapRouter, maxInput);
        operations[i++] = Ops.swapExactOutput(
            uniswapSwapRouter,
            ISwapRouter.ExactOutputParams(
                abi.encodePacked(wsteth, uint24(100), weth),
                address(vault),
                block.timestamp + 1 hours,
                exactOutput,
                maxInput
            )
        );
        operations[i++] = Ops.approve(weth, uniswapSwapRouter, 0);
        assert(operations.length == i);

        assert(IERC20(weth).balanceOf(address(vault)) == maxInput);
        assert(IERC20(wsteth).balanceOf(address(vault)) == 0);

        vm.startPrank(vault.guardian());
        vault.submit(operations);
        vm.stopPrank();
        assert(IERC20(weth).balanceOf(address(vault)) < maxInput);
        assert(IERC20(wsteth).balanceOf(address(vault)) >= exactOutput);
    }

    function _deployFactory() internal {
        AeraV2Factory factory = new AeraV2Factory(wrappedNativeToken);
        v2Factory = address(factory);
        AeraVaultModulesFactory modulesFactory = new AeraVaultModulesFactory(
            v2Factory
        );
        vaultModulesFactory = address(modulesFactory);
        vm.label(v2Factory, "Factory");
        vm.label(vaultModulesFactory, "ModulesFactory");
    }

    function _deployContracts() internal {
        (vaultAddress, assetRegistryAddress, hooksAddress) = run();
        vm.label(vaultAddress, "VAULT");
        vm.label(hooksAddress, "HOOKS");
        vm.label(assetRegistryAddress, "ASSET_REGISTRY");
        vault = AeraVaultV2(payable(vaultAddress));
    }

    function _loadSwapAndDepositOperationsPolygonExactInput()
        internal
        view
        returns (Operation[] memory)
    {
        Operation[] memory operations = new Operation[](4);

        uint256 i = 0;
        uint256 exactInput = 2480252;
        uint256 minOutput = 1293364631244994;
        operations[i++] =
            Ops.approve(usdcPolygon, uniswapSwapRouter, exactInput);
        operations[i++] = Ops.swapExactInput(
            uniswapSwapRouter,
            ISwapRouter.ExactInputParams(
                abi.encodePacked(usdcPolygon, uint24(500), wethPolygon),
                address(this),
                block.timestamp + 1 hours,
                exactInput,
                minOutput
            )
        );

        operations[i++] = Ops.approve(wethPolygon, waPolWETH, minOutput);
        operations[i++] = Ops.deposit(waPolWETH, minOutput, vaultAddress);
        return operations;
    }

    function _loadSwapAndDepositOperationsPolygonExactOutput()
        internal
        view
        returns (Operation[] memory)
    {
        Operation[] memory operations = new Operation[](5);

        uint256 i = 0;
        uint256 maxInput = 2480252;
        uint256 exactOutput = 1293364631244994;
        operations[i++] =
            Ops.approve(usdcPolygon, uniswapSwapRouter, maxInput);
        operations[i++] = Ops.swapExactOutput(
            uniswapSwapRouter,
            ISwapRouter.ExactOutputParams(
                abi.encodePacked(wethPolygon, uint24(500), usdcPolygon),
                address(this),
                block.timestamp + 1 hours,
                exactOutput,
                maxInput
            )
        );

        operations[i++] = Ops.approve(wethPolygon, waPolWETH, exactOutput);
        operations[i++] = Ops.deposit(waPolWETH, exactOutput, vaultAddress);
        operations[i++] =
            Ops.approve(usdcPolygon, uniswapSwapRouter, 0);
        return operations;
    }

    function _loadSwapAndDepositOperationsMainnetExactInput()
        internal
        view
        returns (Operation[] memory)
    {
        uint256 exactInput = 2480252;
        uint256 minOutput = 1293364631244994;
        Operation[] memory operations = new Operation[](4);

        uint256 i = 0;
        operations[i++] = Ops.approve(usdc, uniswapSwapRouter, exactInput);
        operations[i++] = Ops.swapExactInput(
            uniswapSwapRouter,
            ISwapRouter.ExactInputParams(
                abi.encodePacked(usdc, uint24(500), weth),
                address(this),
                block.timestamp + 1 hours,
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

    function _loadSwapAndDepositOperationsMainnetExactOutput()
        internal
        view
        returns (Operation[] memory)
    {
        uint256 maxInput = 2480252;
        uint256 exactOutput = 1293364631244994;
        Operation[] memory operations = new Operation[](5);

        uint256 i = 0;
        operations[i++] = Ops.approve(usdc, uniswapSwapRouter, maxInput);
        operations[i++] = Ops.swapExactOutput(
            uniswapSwapRouter,
            ISwapRouter.ExactOutputParams(
                abi.encodePacked(weth, uint24(500), usdc),
                address(this),
                block.timestamp + 1 hours,
                exactOutput,
                maxInput
            )
        );
        uint256 depositAmount = 20e6;
        operations[i++] = Ops.approve(usdc, waUSDC, depositAmount);
        operations[i++] = Ops.deposit(waUSDC, depositAmount, vaultAddress);
        operations[i++] = Ops.approve(usdc, uniswapSwapRouter, 0);
        assert(operations.length == i);
        return operations;
    }

    function _getAssetRegistryParams(string memory)
        internal
        override
        returns (AssetRegistryParameters memory)
    {
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

    function _getAssetsPolygon()
        internal
        returns (IAssetRegistry.AssetInformation[] memory)
    {
        IAssetRegistry.AssetInformation[] memory assets =
            new IAssetRegistry.AssetInformation[](6);
        uint256 i = 0;
        assets[i++] = IAssetRegistry.AssetInformation({
            asset: IERC20(wethPolygon),
            heartbeat: 24 hours,
            isERC4626: false,
            oracle: AggregatorV2V3Interface(address(0))
        });
        assets[i++] = IAssetRegistry.AssetInformation({
            asset: IERC20(usdcPolygon),
            heartbeat: 24 hours,
            isERC4626: false,
            oracle: AggregatorV2V3Interface(usdcOraclePolygon)
        });
        assets[i++] = IAssetRegistry.AssetInformation({
            asset: IERC20(wstethPolygon),
            heartbeat: 24 hours,
            isERC4626: false,
            oracle: AggregatorV2V3Interface(wstethOraclePolygon)
        });
        assets[i++] = IAssetRegistry.AssetInformation({
            asset: IERC20(wmaticPolygon),
            heartbeat: 24 hours,
            isERC4626: false,
            oracle: AggregatorV2V3Interface(wmaticOraclePolygon)
        });
        assets[i++] = IAssetRegistry.AssetInformation({
            asset: IERC20(waPolUSDC),
            heartbeat: 24 hours,
            isERC4626: true,
            oracle: AggregatorV2V3Interface(address(0))
        });
        assets[i++] = IAssetRegistry.AssetInformation({
            asset: IERC20(waPolWETH),
            heartbeat: 24 hours,
            isERC4626: true,
            oracle: AggregatorV2V3Interface(address(0))
        });

        _sortAssets(assets);
        assertEq(assets.length, i);
        return assets;
    }
}
