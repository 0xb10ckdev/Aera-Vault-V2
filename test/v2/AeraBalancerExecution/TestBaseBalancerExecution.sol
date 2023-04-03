// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {Deployer} from "../../utils/Deployer.sol";
import {IManagedPool} from "../../../../src/v2/dependencies/balancer-labs/interfaces/contracts/pool-utils/IManagedPool.sol";
import {IAsset} from "../../../../src/v2/dependencies/balancer-labs/interfaces/contracts/vault/IAsset.sol";
import {IVault} from "../../../../src/v2/dependencies/balancer-labs/interfaces/contracts/vault/IVault.sol";
import "../../../src/v2/dependencies/chainlink/interfaces/AggregatorV2V3Interface.sol";
import "../../../src/v2/dependencies/openzeppelin/IERC20.sol";
import "../../../src/v2/interfaces/IAssetRegistry.sol";
import "../../../src/v2/interfaces/IBalancerExecution.sol";
import "../../../src/v2/AeraBalancerExecution.sol";
import "../../../src/v2/AeraVaultAssetRegistry.sol";
import "../utils/TestBaseExecution/TestBaseExecution.sol";
import {IOracleMock, OracleMock} from "../../utils/OracleMock.sol";

contract TestBaseBalancerExecution is TestBaseExecution, Deployer {
    address internal _WBTC_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal _USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal _WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal _BVAULT_ADDRESS =
        0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    AeraBalancerExecution balancerExecution;
    AeraVaultAssetRegistry assetRegistry;
    address balancerManagedPoolFactory;
    IAssetRegistry.AssetInformation[] assets;
    uint256 numeraire;

    event StartRebalance(
        IExecution.AssetRebalanceRequest[] requests,
        uint256 startTime,
        uint256 endTime
    );

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_NODE_URI_MAINNET"), 16826100);

        _init();

        _deployAssetRegistry();
        _deployBalancerManagedPoolFactory();
        _deployBalancerExecution();

        for (uint256 i = 0; i < 3; i++) {
            erc20Assets[i].approve(address(balancerExecution), 1);
        }

        balancerExecution.initialize(address(this));

        execution = IExecution(address(balancerExecution));
    }

    function _init() internal {
        erc20Assets.push(IERC20(_WBTC_ADDRESS));
        erc20Assets.push(IERC20(_USDC_ADDRESS));
        erc20Assets.push(IERC20(_WETH_ADDRESS));

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
    }

    function _deployAssetRegistry() internal {
        assetRegistry = new AeraVaultAssetRegistry(assets, numeraire);
    }

    function _deployBalancerManagedPoolFactory() internal {
        address managedPoolAddRemoveTokenLib = deploy(
            "ManagedPoolAddRemoveTokenLib.sol"
        );

        address circuitBreakerLib = deploy("CircuitBreakerLib.sol");

        address protocolFeePercentagesProvider = deploy(
            "ProtocolFeePercentagesProvider.sol",
            abi.encode(_BVAULT_ADDRESS, _ONE, _ONE)
        );

        ExternalLibrary[] memory libraries = new ExternalLibrary[](2);
        libraries[0] = ExternalLibrary({
            name: "ManagedPoolAddRemoveTokenLib",
            addr: managedPoolAddRemoveTokenLib
        });
        libraries[1] = ExternalLibrary({
            name: "CircuitBreakerLib",
            addr: circuitBreakerLib
        });

        balancerManagedPoolFactory = deploy(
            "ManagedPoolFactory",
            libraries,
            abi.encode(_BVAULT_ADDRESS, protocolFeePercentagesProvider)
        );
    }

    function _deployBalancerExecution() internal {
        balancerExecution = new AeraBalancerExecution(_generateVaultParams());
    }

    function _generateVaultParams()
        internal
        returns (
            IBalancerExecution.NewBalancerExecutionParams memory vaultParams
        )
    {
        uint256[] memory weights = new uint256[](3);
        uint256 weightSum;
        for (uint256 i = 0; i < weights.length; i++) {
            weights[i] = _ONE / 3;
            weightSum += weights[i];
        }
        weights[0] = weights[0] + _ONE - weightSum;

        vaultParams = IBalancerExecution.NewBalancerExecutionParams({
            factory: balancerManagedPoolFactory,
            name: "Balancer Execution",
            symbol: "BALANCER EXECUTION",
            poolTokens: erc20Assets,
            weights: weights,
            swapFeePercentage: 1e12,
            assetRegistry: address(assetRegistry),
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
                address(balancerExecution),
                type(uint256).max
            );
        }

        uint256 startTime = block.timestamp + 10;
        uint256 endTime = startTime + 10000;

        vm.expectEmit(true, true, true, true, address(balancerExecution));
        emit StartRebalance(requests, startTime, endTime);

        balancerExecution.startRebalance(requests, startTime, endTime);
    }

    // Simulate swaps
    function _swap(uint256[] memory targetAmounts) internal {
        vm.startPrank(_USER);

        for (uint256 i = 0; i < erc20Assets.length; i++) {
            erc20Assets[i].approve(_BVAULT_ADDRESS, type(uint256).max);
        }

        IVault.FundManagement memory fundManagement = IVault.FundManagement({
            sender: _USER,
            fromInternalBalance: true,
            recipient: payable(_USER),
            toInternalBalance: true
        });

        IExecution.AssetValue[] memory holdings;

        for (uint256 i = 0; i < targetAmounts.length - 1; i++) {
            targetAmounts[i] = (targetAmounts[i] * (_ONE - 1e12)) / _ONE;
            while (true) {
                holdings = balancerExecution.holdings();

                if (holdings[i].value < targetAmounts[i]) {
                    uint256 necessaryAmount = targetAmounts[i] -
                        holdings[i].value;
                    IVault(_BVAULT_ADDRESS).swap(
                        IVault.SingleSwap({
                            poolId: balancerExecution.poolId(),
                            kind: IVault.SwapKind.GIVEN_IN,
                            assetIn: IAsset(address(erc20Assets[i])),
                            assetOut: IAsset(address(erc20Assets[i + 1])),
                            amount: necessaryAmount <
                                (holdings[i].value * 3) / 10
                                ? necessaryAmount
                                : (holdings[i].value * 3) / 10,
                            userData: "0x"
                        }),
                        fundManagement,
                        0,
                        block.timestamp + 100
                    );
                } else if (holdings[i].value > targetAmounts[i]) {
                    uint256 necessaryAmount = holdings[i].value -
                        targetAmounts[i];
                    IVault(_BVAULT_ADDRESS).swap(
                        IVault.SingleSwap({
                            poolId: balancerExecution.poolId(),
                            kind: IVault.SwapKind.GIVEN_OUT,
                            assetIn: IAsset(address(erc20Assets[i + 1])),
                            assetOut: IAsset(address(erc20Assets[i])),
                            amount: necessaryAmount < holdings[i].value / 4
                                ? necessaryAmount
                                : holdings[i].value / 4,
                            userData: "0x"
                        }),
                        fundManagement,
                        type(uint256).max,
                        block.timestamp + 100
                    );
                } else {
                    break;
                }
            }
        }

        vm.stopPrank();
    }

    function _getTargetAmounts()
        internal
        returns (uint256[] memory targetAmounts)
    {
        IERC20[] memory poolTokens = balancerExecution.assets();
        IExecution.AssetValue[] memory holdings = balancerExecution.holdings();
        IAssetRegistry.AssetPriceReading[] memory spotPrices = assetRegistry
            .spotPrices();
        uint256[] memory values = new uint256[](poolTokens.length);
        uint256 totalValue;

        for (uint256 i = 0; i < poolTokens.length; i++) {
            for (uint256 j = 0; j < spotPrices.length; j++) {
                if (poolTokens[i] == spotPrices[j].asset) {
                    values[i] =
                        (holdings[i].value * spotPrices[j].spotPrice) /
                        (10 **
                            IERC20Metadata(address(poolTokens[i])).decimals());
                    totalValue += values[i];

                    break;
                }
            }
        }

        uint256[] memory poolWeights = IManagedPool(
            address(balancerExecution.pool())
        ).getNormalizedWeights();

        targetAmounts = new uint256[](poolTokens.length);

        for (uint256 i = 0; i < poolTokens.length; i++) {
            for (uint256 j = 0; j < spotPrices.length; j++) {
                if (poolTokens[i] == spotPrices[j].asset) {
                    targetAmounts[i] =
                        ((totalValue * poolWeights[i]) *
                            (10 **
                                IERC20Metadata(address(poolTokens[i]))
                                    .decimals())) /
                        _ONE /
                        spotPrices[j].spotPrice;

                    break;
                }
            }
        }
    }
}
