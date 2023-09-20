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
import "periphery/IBalancer.sol";

contract DeployAeraContractsForThreshold is DeployAeraContracts {
    TargetSighashData[] targetSighashAllowlistStorage;
    // Curve
    address[] allowedCurveTargets;
    address[] internal allowedCurveTargetsMainnet = [teth];
    address[] internal allowedCurveTargetsPolygon;
    bytes4[] internal allowedCurveSelectors = [ICurveFiPool.exchange.selector];

    // Balancer
    address[] allowedBalancerTargets;
    address[] internal allowedBalancerTargetsMainnet = [balancerVault];
    address[] internal allowedBalancerTargetsPolygon;
    bytes4[] internal allowedBalancerSelectors = [Balancer.swap.selector];

    // ERC20s
    address[] allowedERC20Targets;
    address[] internal allowedERC20TargetsMainnet = [wsteth, weth, usdc, T];
    address[] internal allowedERC20TargetsPolygon =
        [wstethPolygon, wethPolygon, usdcPolygon, daiPolygon, wmaticPolygon];
    bytes4[] internal allowedERC20Selectors = [IERC20.approve.selector];

    // ERC4626s
    address[] allowedERC4626Targets;
    address[] internal allowedERC4626TargetsMainnet = [waUSDC];
    address[] internal allowedERC4626TargetsPolygon =
        [waPolWETH, waPolUSDC, waPolDAI];
    bytes4[] internal allowedERC4626Selectors = [
        IERC20.approve.selector,
        IERC20.approve.selector,
        IERC4626.deposit.selector,
        IERC4626.withdraw.selector,
        IERC4626.mint.selector,
        IERC4626.redeem.selector
    ];

    // SwapRouters
    address[] allowedSwapRouters;
    address[] internal allowedSwapRoutersMainnet = [uniswapSwapRouter];
    address[] internal allowedSwapRoutersPolygon = [uniswapSwapRouter];
    bytes4[] internal allowedSwapRoutersSelectors = [
        ISwapRouter.exactInput.selector,
        ISwapRouter.exactInputSingle.selector,
        ISwapRouter.exactOutput.selector,
        ISwapRouter.exactOutputSingle.selector
    ];

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

    function addSelector(address target, bytes4 selector) public {
        targetSighashAllowlistStorage.push(
            TargetSighashData({target: target, selector: selector})
        );
    }

    function addSelectors(
        address[] memory targets,
        bytes4[] memory selectors
    ) public {
        for (uint256 i = 0; i < allowedCurveTargets.length; i++) {
            for (uint256 j = 0; j < allowedCurveTargets.length; j++) {
                addSelector(targets[i], selectors[j]);
            }
        }
    }

    function _getTargetSighashAllowList()
        internal
        returns (TargetSighashData[] memory)
    {
        if (block.chainid == 137) {
            allowedCurveTargets = allowedCurveTargetsPolygon;
            allowedBalancerTargets = allowedBalancerTargetsPolygon;
            allowedERC20Targets = allowedERC20TargetsPolygon;
            allowedERC4626Targets = allowedERC4626TargetsPolygon;
            allowedSwapRouters = allowedSwapRoutersPolygon;
        } else if (block.chainid == 1) {
            allowedCurveTargets = allowedCurveTargetsMainnet;
            allowedBalancerTargets = allowedBalancerTargetsMainnet;
            allowedERC20Targets = allowedERC20TargetsMainnet;
            allowedERC4626Targets = allowedERC4626TargetsMainnet;
            allowedSwapRouters = allowedSwapRoutersMainnet;
        } else {
            revert("unsupported chain");
        }
        addSelectors(allowedCurveTargets, allowedCurveSelectors);
        addSelectors(allowedBalancerTargets, allowedBalancerSelectors);
        addSelectors(allowedERC20Targets, allowedERC20Selectors);
        addSelectors(allowedERC4626Targets, allowedERC4626Selectors);
        addSelectors(allowedSwapRouters, allowedSwapRoutersSelectors);
        return targetSighashAllowlistStorage;
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
