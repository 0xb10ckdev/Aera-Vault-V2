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
import {DeployAeraContracts} from "./DeployAeraContracts.s.sol";
import "@chainlink/interfaces/AggregatorV2V3Interface.sol";
import "periphery/ICurveFiPool.sol";

contract DeployAeraContractsForThreshold is DeployAeraContracts {
    using stdJson for string;

    TargetSighashData[] targetSighashAllowlist;

    address[] whitelistedCurveTargets;
    address[] internal whitelistedCurveTargetsMainnet = [
        teth
    ];
    address[] internal whitelistedCurveTargetsPolygon;
    address[] whitelistedERC20Targets;
    address[] internal whitelistedERC20TargetsMainnet = [
        wsteth,
        weth,
        usdc,
        T
    ];
    address[] internal whitelistedERC20TargetsPolygon = [
        wstethPolygon,
        wethPolygon,
        usdcPolygon,
        daiPolygon,
        wmaticPolygon
    ];
    address[] whitelistedERC4626Targets;
    address[] internal whitelistedERC4626TargetsMainnet = [
        waUSDC
    ];
    address[] internal whitelistedERC4626TargetsPolygon = [
        waPolWETH,
        waPolUSDC,
        waPolDAI 
    ];
    address[] whitelistedSwapRouters;
    address[] internal whitelistedSwapRoutersMainnet = [
        uniswapSwapRouter
    ];
    address[] internal whitelistedSwapRoutersPolygon = [
        uniswapSwapRouter
    ];

    function _getAeraVaultHooksParams(string memory relFilePath) 
        internal
        override
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
        owner = owner == address(0) ? _deployerAddress : owner;
        uint256 minDailyValue = json.readUint(".minDailyValue");
        return _getAeraVaultHooksParamsFromSolidity(factory, owner, minDailyValue);
    }

    function _getAeraVaultHooksParamsFromSolidity(address factory, address owner, uint256 minDailyValue)
        internal
        returns (HooksParameters memory)
    {
        if (block.chainid == 137) {
            whitelistedCurveTargets = whitelistedCurveTargetsPolygon;
            whitelistedERC20Targets = whitelistedERC20TargetsPolygon;
            whitelistedERC4626Targets = whitelistedERC4626TargetsPolygon;
            whitelistedSwapRouters = whitelistedSwapRoutersPolygon;
        } else if (block.chainid == 1) {
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
            owner,
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
}
