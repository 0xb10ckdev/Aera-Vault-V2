// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {console} from "forge-std/console.sol";
import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/Script.sol";
import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {AssetValue} from "src/v2/Types.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/AeraVaultHooks.sol";
import "src/v2/TargetSighashLib.sol";
import "@openzeppelin/IERC4626.sol";
import "@openzeppelin/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";

contract WriteHooksJson is Script, Test {
    using stdJson for string;

    address[] internal whitelistedERC20TargetsPolygon = [
        0x03b54A6e9a984069379fae1a4fC4dBAE93B3bCCD, // wstETH
        0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619, // weth
        0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174 //usdc
    ];
    address[] internal whitelistedERC4626TargetsPolygon = [
        0x5e5057b8D220eb8573Bc342136FdF1d869316D18, // waPolWeth
        0x2c616F5Dc3d482010D870d8a01b72cbB1711254A // waPolUsdc
    ];
    address[] internal whitelistedSwapRoutersPolygon = [
        0xE592427A0AEce92De3Edee1F18E0157C05861564 // uniswap
    ];
    address[] internal whitelistedERC20TargetsMainnet = [
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // weth
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48 //usdc
    ];
    address[] internal whitelistedERC4626TargetsMainnet;
    address[] internal whitelistedSwapRoutersMainnet;

    address[] internal whitelistedERC20Targets;
    address[] internal whitelistedERC4626Targets;
    address[] internal whitelistedSwapRouters;
    bytes32[] targetSighashes = new bytes32[](
        whitelistedERC20Targets.length +
        whitelistedERC4626Targets.length +
        whitelistedSwapRouters.length
    );

    function run() public {
        if (block.chainid == 137) {
            whitelistedERC20Targets = whitelistedERC20TargetsPolygon;
            whitelistedERC4626Targets = whitelistedERC4626TargetsPolygon;
            whitelistedSwapRouters = whitelistedSwapRoutersPolygon;
        } else if (block.chainid == 1) {
            whitelistedERC20Targets = whitelistedERC20TargetsMainnet;
            whitelistedERC4626Targets = whitelistedERC4626TargetsMainnet;
            whitelistedSwapRouters = whitelistedSwapRoutersMainnet;
        } else {
            revert("unsupported chain");
        }

        for (uint256 i = 0; i < whitelistedERC20Targets.length; i++) {
            targetSighashes.push(
                TargetSighash.unwrap(
                    TargetSighashLib.toTargetSighash(
                        whitelistedERC20Targets[i], IERC20.approve.selector
                    )
                )
            );
        }
        for (uint256 i = 0; i < whitelistedERC4626Targets.length; i++) {
            targetSighashes.push(
                TargetSighash.unwrap(
                    TargetSighashLib.toTargetSighash(
                        whitelistedERC4626Targets[i], IERC20.approve.selector
                    )
                )
            );
            targetSighashes.push(
                TargetSighash.unwrap(
                    TargetSighashLib.toTargetSighash(
                        whitelistedERC4626Targets[i], IERC4626.deposit.selector
                    )
                )
            );
            targetSighashes.push(
                TargetSighash.unwrap(
                    TargetSighashLib.toTargetSighash(
                        whitelistedERC4626Targets[i],
                        IERC4626.withdraw.selector
                    )
                )
            );
            targetSighashes.push(
                TargetSighash.unwrap(
                    TargetSighashLib.toTargetSighash(
                        whitelistedERC4626Targets[i], IERC4626.mint.selector
                    )
                )
            );
            targetSighashes.push(
                TargetSighash.unwrap(
                    TargetSighashLib.toTargetSighash(
                        whitelistedERC4626Targets[i], IERC4626.redeem.selector
                    )
                )
            );
        }
        for (uint256 i = 0; i < whitelistedSwapRouters.length; i++) {
            targetSighashes.push(
                TargetSighash.unwrap(
                    TargetSighashLib.toTargetSighash(
                        whitelistedSwapRouters[i],
                        ISwapRouter.exactInput.selector
                    )
                )
            );
            targetSighashes.push(
                TargetSighash.unwrap(
                    TargetSighashLib.toTargetSighash(
                        whitelistedSwapRouters[i],
                        ISwapRouter.exactInputSingle.selector
                    )
                )
            );
            targetSighashes.push(
                TargetSighash.unwrap(
                    TargetSighashLib.toTargetSighash(
                        whitelistedSwapRouters[i],
                        ISwapRouter.exactOutput.selector
                    )
                )
            );
            targetSighashes.push(
                TargetSighash.unwrap(
                    TargetSighashLib.toTargetSighash(
                        whitelistedSwapRouters[i],
                        ISwapRouter.exactOutputSingle.selector
                    )
                )
            );
        }

        string memory path =
            string.concat(vm.projectRoot(), "/config/AeraVaultHooks.json");
        string memory json = vm.readFile(path);

        address owner = json.readAddress(".owner");
        uint256 minDailyValue = json.readUint(".minDailyValue");

        vm.serializeAddress("Hooks", "owner", owner);
        vm.serializeUint(
            "Hooks", "minDailyValue", minDailyValue
        );
        vm.writeJson(
            vm.serializeBytes32(
                "Hooks", "targetSighashAllowlist", targetSighashes
            ),
            path
        );
    }
}
