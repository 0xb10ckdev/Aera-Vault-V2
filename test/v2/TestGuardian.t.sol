// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {stdJson} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {Operation, AssetValue} from "src/v2/Types.sol";
import {DeployAeraContractsBase} from
    "script/v2/deploy/DeployAeraContracts.s.sol";
import {DeployScriptBase} from "script/utils/DeployScriptBase.sol";
import "src/v2/AeraVaultV2Factory.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/interfaces/ICustody.sol";
import "src/v2/AeraVaultHooks.sol";
import "src/v2/TargetSighashLib.sol";
import "@openzeppelintest/Strings.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/IERC4626.sol";
import "@openzeppelin/IERC20.sol";
import "@openzeppelin/IERC20IncreaseAllowance.sol";

struct OperationAlpha {
    bytes data;
    address target;
    uint256 value;
}

contract TestGuardian is
    Test,
    DeployScriptBase(false),
    DeployAeraContractsBase
{
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
    address internal guardianAddress = address(1);
    AeraVaultV2 internal vault;
    address weth = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address waPolWETH = 0x5e5057b8D220eb8573Bc342136FdF1d869316D18;
    address swapRouterAddress = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    uint256 fee = 1000000000;
    uint256 maxDailyExecutionLoss = 100000000000000000;
    uint256 minBlockNumber = 46145721;
    string rootPath = string.concat(vm.projectRoot(), "/config/test_guardian");
    Operation[] operations;

    function setUp() public virtual {
        _deployerAddress = address(this);
        vm.label(weth, "WETH");
        vm.label(waPolWETH, "WAPOLWETH");
        vm.label(usdc, "USDC");

        _deployFactory();
        _saveAeraVaultV2Params();
        _deployContracts();
    }

    function test_submitSwapAndDeposit() public {
        if (this.getChainID() != 137) {
            return;
        }
        if (block.number < minBlockNumber) {
            return;
        }
        assertEq(address(this), vault.owner());
        _loadSwapAndDepositOperations();

        AssetValue[] memory amounts = new AssetValue[](2);
        amounts[0] = AssetValue({asset: IERC20(usdc), value: 25e6});
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
        vault.submit(operations);
        // fails with no fees available when no vm.warp
        vm.expectRevert(
            abi.encodePacked(
                ICustody.Aera__NoAvailableFeeForCaller.selector,
                abi.encode(vault.guardian())
            )
        );
        vault.claim();
        vm.stopPrank();
    }

    function _deployFactory() internal {
        AeraVaultV2Factory factory = new AeraVaultV2Factory(weth);
        factoryAddress = address(factory);
        vm.label(factoryAddress, "Factory");
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
            vm.serializeAddress(
                "Deployments", "aeraVaultV2Factory", factoryAddress
            ),
            aeraVaultV2Path
        );
    }

    function _deployContracts() internal {
        _writeHooksParams();
        (assetRegistryAddress, vaultAddress, hooksAddress) =
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

    function _loadSwapAndDepositOperations() internal {
        operations.push(
            Operation({
                data: abi.encodePacked(
                    IERC20.approve.selector,
                    abi.encode(address(swapRouterAddress), 2480252)
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
                target: swapRouterAddress,
                value: 0
            })
        );

        operations.push(
            Operation({
                data: abi.encodePacked(
                    IERC20.approve.selector,
                    abi.encode(waPolWETH, 1293364631244994)
                    ),
                target: weth,
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

    function _writeHooksParams() internal {
        uint256[8] memory sighashes = [
            TargetSighash.unwrap(
                TargetSighashLib.toTargetSighash(
                    swapRouterAddress, ISwapRouter.exactInput.selector
                )
            ),
            TargetSighash.unwrap(
                TargetSighashLib.toTargetSighash(
                    swapRouterAddress, ISwapRouter.exactInputSingle.selector
                )
            ),
            TargetSighash.unwrap(
                TargetSighashLib.toTargetSighash(
                    swapRouterAddress, ISwapRouter.exactOutput.selector
                )
            ),
            TargetSighash.unwrap(
                TargetSighashLib.toTargetSighash(
                    swapRouterAddress, ISwapRouter.exactOutputSingle.selector
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
        uint256[] memory dynamicSighashArray = new uint256[](8);
        for (uint256 i = 0; i < 8; i++) {
            dynamicSighashArray[i] = sighashes[i];
        }

        string memory aeraVaultHooksPath =
            string.concat(rootPath, "/AeraVaultHooks.json");

        vm.serializeAddress("Hooks", "owner", address(this));
        vm.serializeUint(
            "Deployments", "maxDailyExecutionLoss", maxDailyExecutionLoss
        );
        string memory json;
        json = vm.serializeUint(
            "Deployments", "targetSighashAllowlist", dynamicSighashArray
        );

        vm.writeJson(json, aeraVaultHooksPath);
    }

    function getChainID() external view returns (uint256) {
        uint256 id;
        assembly {
            id := chainid()
        }
        return id;
    }
}
