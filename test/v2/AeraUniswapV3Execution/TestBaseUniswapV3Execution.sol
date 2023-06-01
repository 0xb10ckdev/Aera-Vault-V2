// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Deployer} from "../../utils/Deployer.sol";
import "../../../src/v2/dependencies/chainlink/interfaces/AggregatorV2V3Interface.sol";
import "../../../src/v2/dependencies/openzeppelin/IERC20.sol";
import "../../../src/v2/interfaces/IAssetRegistry.sol";
import "../../../src/v2/interfaces/IUniswapV3Execution.sol";
import "../../../src/v2/AeraUniswapV3Execution.sol";
import "../../../src/v2/AeraVaultAssetRegistry.sol";
import "../utils/TestBaseExecution/TestBaseExecution.sol";
import {IOracleMock, OracleMock} from "../../utils/OracleMock.sol";

contract TestBaseUniswapV3Execution is TestBaseExecution, Deployer {
    address internal _WBTC_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal _USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal _WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    AeraUniswapV3Execution uniswapV3Execution;
    AeraVaultAssetRegistry assetRegistry;
    IAssetRegistry.AssetInformation[] assets;
    address vehicle;
    uint256 numeraire;
    uint256 maxSlippage;
    PoolPreference[] poolPreferences;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_NODE_URI_MAINNET"), 16826100);

        _init();

        _deployAssetRegistry();
        _deployUniswapV3Execution();

        for (uint256 i = 0; i < 3; i++) {
            erc20Assets[i].approve(address(uniswapV3Execution), 1);
        }

        uniswapV3Execution.initialize(address(this));

        execution = IExecution(address(uniswapV3Execution));
    }

    function _init() internal {
        erc20Assets.push(IERC20(_WBTC_ADDRESS));
        erc20Assets.push(IERC20(_USDC_ADDRESS));
        erc20Assets.push(IERC20(_WETH_ADDRESS));
        vehicle = _WETH_ADDRESS;
        maxSlippage = 1e16; // 1%

        // USDC
        numeraire = 1;

        for (uint256 i = 0; i < 3; i++) {
            deal(address(erc20Assets[i]), address(this), 1_000_000e18);
            deal(address(erc20Assets[i]), _USER, 1_000_000e18);

            assets.push(
                IAssetRegistry.AssetInformation({
                    asset: erc20Assets[i],
                    isERC4626: false,
                    withdrawable: true,
                    oracle: AggregatorV2V3Interface(
                        i == numeraire ? address(0) : address(new OracleMock(6))
                    )
                })
            );
        }

        IOracleMock(address(assets[0].oracle)).setLatestAnswer(
            int256(15_000e6)
        );
        IOracleMock(address(assets[2].oracle)).setLatestAnswer(int256(1_000e6));

        poolPreferences = new PoolPreference[](0);
    }

    function _deployAssetRegistry() internal {
        assetRegistry = new AeraVaultAssetRegistry(assets, numeraire);
    }

    function _deployUniswapV3Execution() internal {
        uniswapV3Execution = new AeraUniswapV3Execution(
            _generateExecutionParams()
        );
    }

    function _generateExecutionParams()
        internal
        returns (
            IUniswapV3Execution.NewUniswapV3ExecutionParams
                memory executionParams
        )
    {
        uint256[] memory weights = new uint256[](3);
        uint256 weightSum;
        for (uint256 i = 0; i < weights.length; i++) {
            weights[i] = _ONE / 3;
            weightSum += weights[i];
        }
        weights[0] = weights[0] + _ONE - weightSum;

        executionParams = IUniswapv3Execution.NewUniswapv3ExecutionParams({
            assetRegistry: address(assetRegistry),
            vehicle: address(vehicle),
            maxSlippage: maxSlippage,
            poolPreference: poolPreferences,
            description: "Test Execution"
        });
    }

    function _generateRequestWith2Assets()
        internal
        returns (IExecution.AssetRebalanceRequest[] memory requests)
    {
        requests = new IExecution.AssetRebalanceRequest[](2);

        // WBTC
        requests[0] = IExecution.AssetRebalanceRequest({
            asset: erc20Assets[0],
            amount: 5e8,
            weight: 0.69e18
        });
        // USDC
        requests[1] = IExecution.AssetRebalanceRequest({
            asset: erc20Assets[1],
            amount: 80_000e6,
            weight: 0.31e18
        });
    }

    function _generateRequestWith3Assets()
        internal
        returns (IExecution.AssetRebalanceRequest[] memory requests)
    {
        requests = new IExecution.AssetRebalanceRequest[](3);

        // WBTC
        requests[0] = IExecution.AssetRebalanceRequest({
            asset: erc20Assets[0],
            amount: 5e8,
            weight: 0.34e18
        });
        // USDC
        requests[1] = IExecution.AssetRebalanceRequest({
            asset: erc20Assets[1],
            amount: 80_000e6,
            weight: 0.31e18
        });
        // WETH
        requests[2] = IExecution.AssetRebalanceRequest({
            asset: erc20Assets[2],
            amount: 100e18,
            weight: 0.35e18
        });
    }

    function _startRebalance(
        IExecution.AssetRebalanceRequest[] memory requests
    ) internal {
        for (uint256 i = 0; i < requests.length; i++) {
            requests[i].asset.approve(
                address(uniswapV3Execution),
                type(uint256).max
            );
        }

        uint256 startTime = block.timestamp + 10;
        uint256 endTime = startTime + 10000;

        vm.expectEmit(true, true, true, true, address(uniswapV3Execution));
        emit StartRebalance(requests, startTime, endTime);

        uniswapV3Execution.startRebalance(requests, startTime, endTime);
    }

    function _getScaler(IERC20 token) internal returns (uint256) {
        return 10 ** IERC20Metadata(address(token)).decimals();
    }
}
