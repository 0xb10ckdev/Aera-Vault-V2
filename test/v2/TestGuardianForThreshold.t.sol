// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {stdJson} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {Operation, AssetValue} from "src/v2/Types.sol";
import {DeployAeraContractsForThreshold} from "script/v2/deploy/DeployAeraContractsForThreshold.s.sol";
import {DeployScriptBase} from "script/utils/DeployScriptBase.sol";
import "src/v2/AeraV2Factory.sol";
import "src/v2/AeraVaultModulesFactory.sol";
import "src/v2/AeraVaultV2.sol";
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

    using stdJson for string;

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
        _saveAeraVaultV2Params();
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

    function _saveAeraVaultV2Params() internal {
        string memory aeraVaultV2Path =
            string.concat(rootPath, "/AeraVaultV2.json");

        vm.serializeAddress("Deployments", "owner", address(this));
        vm.serializeString("Deployments", "description", "Test Vault");
        vm.serializeUint("Deployments", "fee", fee);
        vm.serializeAddress("Deployments", "guardian", guardianAddress);
        vm.serializeAddress("Deployments", "feeRecipient", guardianAddress);
        vm.writeJson(
            vm.serializeAddress("Deployments", "v2Factory", factoryAddress),
            aeraVaultV2Path
        );
    }

    function _deployContracts() internal {
        _writeHooksParams();
        _writeAssetRegistryParams();
        (vaultAddress, assetRegistryAddress, hooksAddress) =
        runFromSpecifiedConfigPaths(
            0,
            "/config/test_guardian/AeraVaultAssetRegistry.json",
            "/config/test_guardian/AeraVaultV2.json",
            "/config/test_guardian/AeraVaultHooks.json",
            false
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

    function _writeAssetRegistryParams() internal {
        string memory aeraVaultAssetRegistryReadPath;
        // TODO: remove json and just deploy using solidity variables
        address numeraireToken;
        address feeToken;
        if (block.chainid == 137 ) {
            aeraVaultAssetRegistryReadPath = string.concat(rootPath, "/AeraVaultAssetRegistryPolygon.json");
            numeraireToken = wethPolygon;
            feeToken = wethPolygon;
        } else {
            aeraVaultAssetRegistryReadPath = string.concat(rootPath, "/AeraVaultAssetRegistryMainnet.json");
            numeraireToken = weth;
            feeToken = weth;
        }
        string memory aeraVaultAssetRegistryPath =
            string.concat(rootPath, "/AeraVaultAssetRegistry.json");

        setAddress(aeraVaultAssetRegistryPath, "owner", address(this));
        setAddress(aeraVaultAssetRegistryPath, "numeraireToken", numeraireToken);
        setAddress(aeraVaultAssetRegistryPath, "feeToken", feeToken);
        setAddress(aeraVaultAssetRegistryPath, "sequencer", address(0));
        setAddress(aeraVaultAssetRegistryPath, "assetRegistryFactory", modulesFactoryAddress);
        // TODO: serialize the struct of assets?
    }

    function _writeHooksParams() internal {
        bytes32[11] memory sighashes = [
            TargetSighash.unwrap(
                TargetSighashLib.toTargetSighash(usdcPolygon, IERC20.approve.selector)
            ),
            TargetSighash.unwrap(
                TargetSighashLib.toTargetSighash(wethPolygon, IERC20.approve.selector)
            ),
            TargetSighash.unwrap(
                TargetSighashLib.toTargetSighash(wstethPolygon, IERC20.approve.selector)
            ),
            TargetSighash.unwrap(
                TargetSighashLib.toTargetSighash(
                    uniswapSwapRouter, ISwapRouter.exactInput.selector
                )
            ),
            TargetSighash.unwrap(
                TargetSighashLib.toTargetSighash(
                    uniswapSwapRouter, ISwapRouter.exactInputSingle.selector
                )
            ),
            TargetSighash.unwrap(
                TargetSighashLib.toTargetSighash(
                    uniswapSwapRouter, ISwapRouter.exactOutput.selector
                )
            ),
            TargetSighash.unwrap(
                TargetSighashLib.toTargetSighash(
                    uniswapSwapRouter, ISwapRouter.exactOutputSingle.selector
                )
            ),
            TargetSighash.unwrap(
                TargetSighashLib.toTargetSighash(
                    waPolWETH, IERC4626.deposit.selector
                )
            ),
            TargetSighash.unwrap(
                TargetSighashLib.toTargetSighash(
                    waPolWETH, IERC4626.withdraw.selector
                )
            ),
            TargetSighash.unwrap(
                TargetSighashLib.toTargetSighash(waPolWETH, IERC4626.mint.selector)
            ),
            TargetSighash.unwrap(
                TargetSighashLib.toTargetSighash(
                    waPolWETH, IERC4626.redeem.selector
                )
            )
        ];
        bytes32[] memory dynamicSighashArray = new bytes32[](11);
        for (uint256 i = 0; i < sighashes.length; i++) {
            dynamicSighashArray[i] = sighashes[i];
        }

        string memory aeraVaultHooksPath =
            string.concat(rootPath, "/AeraVaultHooks.json");

        setUint(aeraVaultHooksPath, "minDailyValue", minDailyValue);
        setAddress(aeraVaultHooksPath, "hooksFactory", modulesFactoryAddress);
        setAddress(aeraVaultHooksPath, "owner", address(this));
    }

    function setAddress(string memory filepath, string memory jsonPath, address value) public {
        vm.writeJson(vm.toString(value), filepath, string(abi.encodePacked(".", jsonPath)));
    }

    function setUint(string memory filepath, string memory jsonPath, uint256 value) public {
        vm.writeJson(vm.toString(value), filepath, string(abi.encodePacked(".", jsonPath)));
    }
}
