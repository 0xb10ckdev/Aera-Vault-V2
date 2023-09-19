// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Test} from "forge-std/Test.sol";
import {Operation, AssetValue} from "src/v2/Types.sol";
import {DeployAeraContractsForThreshold} from "script/v2/deploy/DeployAeraContractsForThreshold.s.sol";
import {DeployScriptBase} from "script/utils/DeployScriptBase.sol";
import "src/v2/AeraV2Factory.sol";
import "src/v2/AeraVaultModulesFactory.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/interfaces/IAssetRegistry.sol";
import "src/v2/interfaces/IVault.sol";
import "src/v2/AeraVaultHooks.sol";
import "src/v2/TargetSighashLib.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/IERC4626.sol";
import "@openzeppelin/IERC20.sol";
import "@openzeppelin/IERC20IncreaseAllowance.sol";
import "forge-std/console.sol";

struct OperationAlpha {
    bytes data;
    address target;
    uint256 value;
}

contract TestGuardianForThreshold is Test, DeployScriptBase, DeployAeraContractsForThreshold {
    bytes4 internal constant _APPROVE_SELECTOR = IERC20.approve.selector;

    bytes4 internal constant _INCREASE_ALLOWANCE_SELECTOR =
        IERC20IncreaseAllowance.increaseAllowance.selector;

    uint256 internal senderPrivateKey;
    address internal senderAddress;
    address internal vaultAddress;
    address internal hooksAddress;
    address internal assetRegistryAddress;
    address internal factoryAddress;
    address internal modulesFactoryAddress;
    address internal guardianAddress = address(1);
    address internal wrappedNativeToken;
    AeraVaultV2 internal vault;
    uint256 fee = 0;
    uint256 minDailyValue = 900000000000000000;
    uint256 minBlockNumberPolygon = 46145721;
    uint256 minBlockNumberMainnet = 18171594;
    string rootPath = string.concat(vm.projectRoot(), "/config/test_guardian");
    Operation[] operations;
    IAssetRegistry.AssetInformation[] assets;

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
        _loadSwapAndDepositOperationsPolygon();

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

    function _deployFactory() internal {
        AeraV2Factory factory = new AeraV2Factory(wrappedNativeToken);
        factoryAddress = address(factory);
        AeraVaultModulesFactory modulesFactory = new AeraVaultModulesFactory(factoryAddress);
        modulesFactoryAddress = address(modulesFactory);
        vm.label(factoryAddress, "Factory");
        vm.label(modulesFactoryAddress, "ModulesFactory");
    }

    function _deployContracts() internal {
        VaultParameters memory vaultParameters = VaultParameters(
            address(this),
            guardianAddress,
            guardianAddress,
            fee
        );

        HooksParameters memory hooksParameters = _getAeraVaultHooksParamsFromSolidity(
            modulesFactoryAddress, 
            address(this), 
            minDailyValue
        );

        AssetRegistryParameters memory assetRegistryParameters = _getAssetRegistryParameters();
        (vaultAddress, assetRegistryAddress, hooksAddress) =
        runFromPassedParams(
            bytes32("0"),
            factoryAddress,
            "test threshold vault",
            vaultParameters,
            assetRegistryParameters,
            hooksParameters,
            true
        );
        vm.label(vaultAddress, "VAULT");
        vm.label(hooksAddress, "HOOKS");
        vm.label(assetRegistryAddress, "ASSET_REGISTRY");
        vault = AeraVaultV2(payable(vaultAddress));
    }

    function _loadSwapAndDepositOperationsPolygon() internal {
        operations.push(
            Operation({
                data: abi.encodePacked(
                    IERC20.approve.selector,
                    abi.encode(address(uniswapSwapRouter), 2480252)
                    ),
                target: usdcPolygon,
                value: 0
            })
        );

        operations.push(
            Operation({
                data: abi.encodePacked(
                    ISwapRouter.exactInput.selector,
                    abi.encode(
                        ISwapRouter.ExactInputParams(
                            abi.encodePacked(usdcPolygon, uint24(500), wethPolygon),
                            address(this),
                            block.timestamp + 3600,
                            2480252,
                            1293364631244994
                        )
                    )
                    ),
                target: uniswapSwapRouter,
                value: 0
            })
        );

        operations.push(
            Operation({
                data: abi.encodePacked(
                    IERC20.approve.selector,
                    abi.encode(waPolWETH, 1293364631244994)
                    ),
                target: wethPolygon,
                value: 0
            })
        );

        operations.push(
            Operation({
                data: abi.encodePacked(
                    IERC4626.deposit.selector,
                    abi.encode(1293364631244994, vaultAddress)
                    ),
                target: waPolWETH,
                value: 0
            })
        );
    }

    // TODO: also test t-token and curve swap
    function _loadSwapAndDepositOperationsMainnet() internal {
        operations.push(
            Operation({
                data: abi.encodePacked(
                    IERC20.approve.selector,
                    abi.encode(address(uniswapSwapRouter), 2480252)
                    ),
                target: usdc,
                value: 0
            })
        );

        operations.push(
            Operation({
                data: abi.encodePacked(
                    ISwapRouter.exactInput.selector,
                    abi.encode(
                        ISwapRouter.ExactInputParams(
                            abi.encodePacked(usdc, uint24(500), weth),
                            address(this),
                            block.timestamp + 3600,
                            2480252,
                            1293364631244994
                        )
                    )
                    ),
                target: uniswapSwapRouter,
                value: 0
            })
        );

        operations.push(
            Operation({
                data: abi.encodePacked(
                    IERC20.approve.selector,
                    abi.encode(waUSDC, 20e6)
                    ),
                target: usdc,
                value: 0
            })
        );

        operations.push(
            Operation({
                data: abi.encodePacked(
                    IERC4626.deposit.selector,
                    abi.encode(20e6, vaultAddress)
                    ),
                target: waUSDC,
                value: 0
            })
        );
    }



    function getSelector(bytes calldata data) public pure returns (bytes4) {
        return bytes4(data[0:4]);
    }

    function _isAllowanceSelector(bytes4 selector)
        internal
        pure
        returns (bool isAllowanceSelector)
    {
        return selector == _APPROVE_SELECTOR
            || selector == _INCREASE_ALLOWANCE_SELECTOR;
    }

    function _getAssetRegistryParameters() internal returns (AssetRegistryParameters memory) {
        address numeraireToken;
        address feeToken;
        if (block.chainid == 137 ) {
            numeraireToken = wethPolygon;
            feeToken = wethPolygon;
            assets.push(
                IAssetRegistry.AssetInformation({
                    asset: IERC20(wethPolygon),
                    heartbeat: 86400,
                    isERC4626: false,
                    oracle: AggregatorV2V3Interface(address(0))
                })
            );
            assets.push(
                IAssetRegistry.AssetInformation({
                    asset: IERC20(usdcPolygon),
                    heartbeat: 86400,
                    isERC4626: false,
                    oracle: AggregatorV2V3Interface(usdcOraclePolygon)
                })
            );
            assets.push(
                IAssetRegistry.AssetInformation({
                    asset: IERC20(usdcPolygon),
                    heartbeat: 86400,
                    isERC4626: false,
                    oracle: AggregatorV2V3Interface(usdcOraclePolygon)
                })
            );
            assets.push(
                IAssetRegistry.AssetInformation({
                    asset: IERC20(wstethPolygon),
                    heartbeat: 86400,
                    isERC4626: false,
                    oracle: AggregatorV2V3Interface(wstethOraclePolygon)
                })
            );
            assets.push(
                IAssetRegistry.AssetInformation({
                    asset: IERC20(wmaticPolygon),
                    heartbeat: 86400,
                    isERC4626: false,
                    oracle: AggregatorV2V3Interface(wmaticOraclePolygon)
                })
            );
            assets.push(
                IAssetRegistry.AssetInformation({
                    asset: IERC20(waPolUSDC),
                    heartbeat: 86400,
                    isERC4626: true,
                    oracle: AggregatorV2V3Interface(address(0))
                })
            );
            assets.push(
                IAssetRegistry.AssetInformation({
                    asset: IERC20(waPolWETH),
                    heartbeat: 86400,
                    isERC4626: true,
                    oracle: AggregatorV2V3Interface(address(0))
                })
            );
        } else {
            numeraireToken = weth;
            feeToken = weth;
            assets.push(
                IAssetRegistry.AssetInformation({
                    asset: IERC20(weth),
                    heartbeat: 86400,
                    isERC4626: false,
                    oracle: AggregatorV2V3Interface(address(0))
                })
            );
            assets.push(
                IAssetRegistry.AssetInformation({
                    asset: IERC20(usdc),
                    heartbeat: 86400,
                    isERC4626: false,
                    oracle: AggregatorV2V3Interface(usdcOracle)
                })
            );
            assets.push(
                IAssetRegistry.AssetInformation({
                    asset: IERC20(wsteth),
                    heartbeat: 86400,
                    isERC4626: false,
                    oracle: AggregatorV2V3Interface(wstethOracle)
                })
            );
            assets.push(
                IAssetRegistry.AssetInformation({
                    asset: IERC20(T),
                    heartbeat: 86400,
                    isERC4626: false,
                    oracle: AggregatorV2V3Interface(TOracle)
                })
            );

            assets.push(
                IAssetRegistry.AssetInformation({
                    asset: IERC20(waUSDC),
                    heartbeat: 86400,
                    isERC4626: true,
                    oracle: AggregatorV2V3Interface(address(0))
                })
            );
        }

        _sortAssets();
        return AssetRegistryParameters(
            modulesFactoryAddress,
            address(this),
            assets,
            IERC20(numeraireToken),
            IERC20(feeToken),
            AggregatorV2V3Interface(address(0))
        );
    }

    function _sortAssets() internal {
        uint256 n = assets.length;

        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - i - 1; j++) {
                if (assets[j].asset > assets[j + 1].asset) {
                    IAssetRegistry.AssetInformation storage tmp = assets[j];
                    assets[j] = assets[j+1];
                    assets[j+1] = tmp;
                }
            }
        }
    }
}
