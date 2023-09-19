// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

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
    TargetSighashData[] targetSighashAllowlistStorage;
    address[] allowlistedCurveTargets;
    address[] internal allowlistedCurveTargetsMainnet = [teth];
    address[] internal allowlistedCurveTargetsPolygon;
    address[] allowlistedERC20Targets;
    address[] internal allowlistedERC20TargetsMainnet = [wsteth, weth, usdc, T];
    address[] internal allowlistedERC20TargetsPolygon =
        [wstethPolygon, wethPolygon, usdcPolygon, daiPolygon, wmaticPolygon];
    address[] allowlistedERC4626Targets;
    address[] internal allowlistedERC4626TargetsMainnet = [waUSDC];
    address[] internal allowlistedERC4626TargetsPolygon =
        [waPolWETH, waPolUSDC, waPolDAI];
    address[] allowlistedSwapRouters;
    address[] internal allowlistedSwapRoutersMainnet = [uniswapSwapRouter];
    address[] internal allowlistedSwapRoutersPolygon = [uniswapSwapRouter];

    address v2Factory = 0x6b8d4485e11aae228a32FAe5802c6d4BA25EA404;
    address vaultModulesFactory = 0xC6149001299f3894FA2554e518b40961Da554eE0;
    address internal guardianAddress =
        0xacEb23F3d96a2e3BE44306D9e57aaF9a0d1FFD74;
    address internal feeRecipient = guardianAddress;
    uint256 minDailyValue = 0.9e18;
    uint256 fee = 0;
    string description = "Threshold Vault";

    /// @inheritdoc DeployAeraContracts
    function run()
        public
        override
        returns (
            address deployedVault,
            address deployedAssetRegistry,
            address deployedHooks
        )
    {
        return run(bytes32("346"));
    }

    function _getAeraVaultV2Params(string memory)
        internal
        view
        override
        returns (
            address,
            VaultParameters memory vaultParameters,
            string memory
        )
    {
        return (
            v2Factory,
            VaultParameters(
                address(this), guardianAddress, guardianAddress, fee
                ),
            description
        );
    }

    function _getAeraVaultHooksParams(string memory)
        internal
        override
        returns (HooksParameters memory)
    {
        TargetSighashData[] memory targetSighashAllowlist =
            _getTargetSighashAllowList();

        return HooksParameters(
            vaultModulesFactory,
            _deployerAddress,
            minDailyValue,
            targetSighashAllowlist
        );
    }

    function _getTargetSighashAllowList()
        internal
        returns (TargetSighashData[] memory)
    {
        if (block.chainid == 137) {
            allowlistedCurveTargets = allowlistedCurveTargetsPolygon;
            allowlistedERC20Targets = allowlistedERC20TargetsPolygon;
            allowlistedERC4626Targets = allowlistedERC4626TargetsPolygon;
            allowlistedSwapRouters = allowlistedSwapRoutersPolygon;
        } else if (block.chainid == 1) {
            allowlistedCurveTargets = allowlistedCurveTargetsMainnet;
            allowlistedERC20Targets = allowlistedERC20TargetsMainnet;
            allowlistedERC4626Targets = allowlistedERC4626TargetsMainnet;
            allowlistedSwapRouters = allowlistedSwapRoutersMainnet;
        } else {
            revert("unsupported chain");
        }
        for (uint256 i = 0; i < allowlistedCurveTargets.length; i++) {
            targetSighashAllowlistStorage.push(
                TargetSighashData({
                    target: allowlistedCurveTargetsMainnet[i],
                    selector: ICurveFiPool.exchange.selector
                })
            );
        }
        for (uint256 i = 0; i < allowlistedERC20Targets.length; i++) {
            targetSighashAllowlistStorage.push(
                TargetSighashData({
                    target: allowlistedERC20Targets[i],
                    selector: IERC20.approve.selector
                })
            );
        }
        for (uint256 i = 0; i < allowlistedERC4626Targets.length; i++) {
            targetSighashAllowlistStorage.push(
                TargetSighashData({
                    target: allowlistedERC4626Targets[i],
                    selector: IERC20.approve.selector
                })
            );
            targetSighashAllowlistStorage.push(
                TargetSighashData({
                    target: allowlistedERC4626Targets[i],
                    selector: IERC4626.deposit.selector
                })
            );
            targetSighashAllowlistStorage.push(
                TargetSighashData({
                    target: allowlistedERC4626Targets[i],
                    selector: IERC4626.withdraw.selector
                })
            );
            targetSighashAllowlistStorage.push(
                TargetSighashData({
                    target: allowlistedERC4626Targets[i],
                    selector: IERC4626.mint.selector
                })
            );
            targetSighashAllowlistStorage.push(
                TargetSighashData({
                    target: allowlistedERC4626Targets[i],
                    selector: IERC4626.redeem.selector
                })
            );
        }
        for (uint256 i = 0; i < allowlistedSwapRouters.length; i++) {
            targetSighashAllowlistStorage.push(
                TargetSighashData({
                    target: allowlistedSwapRouters[i],
                    selector: ISwapRouter.exactInput.selector
                })
            );
            targetSighashAllowlistStorage.push(
                TargetSighashData({
                    target: allowlistedSwapRouters[i],
                    selector: ISwapRouter.exactInputSingle.selector
                })
            );
            targetSighashAllowlistStorage.push(
                TargetSighashData({
                    target: allowlistedSwapRouters[i],
                    selector: ISwapRouter.exactOutput.selector
                })
            );
            targetSighashAllowlistStorage.push(
                TargetSighashData({
                    target: allowlistedSwapRouters[i],
                    selector: ISwapRouter.exactOutputSingle.selector
                })
            );
        }
        TargetSighashData[] memory targetSighashAllowlistMem =
        new TargetSighashData[](
                targetSighashAllowlistStorage.length
            );
        for (uint256 i = 0; i < targetSighashAllowlistStorage.length; i++) {
            targetSighashAllowlistMem[i] = targetSighashAllowlistStorage[i];
        }
        return targetSighashAllowlistMem;
    }

    function _getAssetRegistryParams(string memory)
        internal
        virtual
        override
        returns (AssetRegistryParameters memory)
    {
        IAssetRegistry.AssetInformation[] memory assets = _getAssets();
        address numeraireToken = weth;
        address feeToken = weth;
        return AssetRegistryParameters(
            vaultModulesFactory,
            address(this),
            assets,
            IERC20(numeraireToken),
            IERC20(feeToken),
            AggregatorV2V3Interface(address(0))
        );
    }

    function _getAssets()
        internal
        returns (IAssetRegistry.AssetInformation[] memory)
    {
        IAssetRegistry.AssetInformation[] memory assets =
            new IAssetRegistry.AssetInformation[](5);
        uint256 i = 0;
        assets[i++] = IAssetRegistry.AssetInformation({
            asset: IERC20(weth),
            heartbeat: 86400,
            isERC4626: false,
            oracle: AggregatorV2V3Interface(address(0))
        });
        assets[i++] = IAssetRegistry.AssetInformation({
            asset: IERC20(usdc),
            heartbeat: 86400,
            isERC4626: false,
            oracle: AggregatorV2V3Interface(usdcOracle)
        });
        assets[i++] = IAssetRegistry.AssetInformation({
            asset: IERC20(wsteth),
            heartbeat: 86400,
            isERC4626: false,
            oracle: AggregatorV2V3Interface(wstethOracle)
        });
        assets[i++] = IAssetRegistry.AssetInformation({
            asset: IERC20(T),
            heartbeat: 86400,
            isERC4626: false,
            oracle: AggregatorV2V3Interface(TOracle)
        });
        assets[i++] = IAssetRegistry.AssetInformation({
            asset: IERC20(waUSDC),
            heartbeat: 86400,
            isERC4626: true,
            oracle: AggregatorV2V3Interface(address(0))
        });
        _sortAssets(assets);
        assertEq(assets.length, i);
        return assets;
    }

    function _sortAssets(IAssetRegistry.AssetInformation[] memory assets)
        internal
        pure
    {
        IAssetRegistry.AssetInformation memory tmpAsset;
        uint256 n = assets.length;

        for (uint256 i = 0; i < n - 1; i++) {
            for (uint256 j = 0; j < n - i - 1; j++) {
                if (assets[j].asset > assets[j + 1].asset) {
                    tmpAsset = IAssetRegistry.AssetInformation({
                        asset: assets[j].asset,
                        heartbeat: assets[j].heartbeat,
                        isERC4626: assets[j].isERC4626,
                        oracle: assets[j].oracle
                    });
                    assets[j] = assets[j + 1];
                    assets[j + 1] = tmpAsset;
                }
            }
        }
    }
}
