// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "solmate/tokens/ERC20.sol";
import {TestBase} from "../../utils/TestBase.sol";
import {Deployer} from "../../utils/Deployer.sol";
import "../../../src/v2/dependencies/chainlink/interfaces/AggregatorV2V3Interface.sol";
import "../../../src/v2/dependencies/openzeppelin/IERC20.sol";
import "../../../src/v2/interfaces/IAssetRegistry.sol";
import "../../../src/v2/interfaces/IExecution.sol";
import "../../../src/v2/AeraBalancerExecution.sol";
import "../../../src/v2/AeraVaultAssetRegistry.sol";
import {IOracleMock, OracleMock} from "../../utils/OracleMock.sol";

contract TestBaseBalancerExecution is Deployer, TestBase {
    address internal _WBTC_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal _USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal _WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal _BVAULT_ADDRESS =
        0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    AeraBalancerExecution balancerExecution;
    AeraVaultAssetRegistry assetRegistry;
    IAssetRegistry.AssetInformation[] assets;
    IERC20[] erc20Assets;
    uint256 numeraire;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_NODE_URI_MAINNET"), 16826100);

        _deploy();
    }

    function _deploy() internal {
        _init();

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

        address managedPoolFactory = deploy(
            "ManagedPoolFactory",
            libraries,
            abi.encode(_BVAULT_ADDRESS, protocolFeePercentagesProvider)
        );

        assetRegistry = new AeraVaultAssetRegistry(assets, numeraire);

        uint256[] memory weights = new uint256[](3);
        uint256 weightSum;
        for (uint256 i = 0; i < weights.length; i++) {
            weights[i] = _ONE / 3;
            weightSum += weights[i];
        }
        weights[0] = weights[0] + _ONE - weightSum;

        IExecution.NewVaultParams memory vaultParams = IExecution
            .NewVaultParams({
                factory: managedPoolFactory,
                name: "Balancer Execution",
                symbol: "BALANCER EXECUTION",
                poolTokens: erc20Assets,
                weights: weights,
                swapFeePercentage: 1e12,
                assetRegistry: address(assetRegistry),
                description: "Test Execution"
            });
        balancerExecution = new AeraBalancerExecution(vaultParams);

        for (uint256 i = 0; i < 3; i++) {
            erc20Assets[i].approve(address(balancerExecution), 1);
        }

        balancerExecution.initialize(address(this));
    }

    function _init() internal {
        erc20Assets.push(IERC20(_WBTC_ADDRESS));
        erc20Assets.push(IERC20(_USDC_ADDRESS));
        erc20Assets.push(IERC20(_WETH_ADDRESS));

        // USDC
        numeraire = 1;

        for (uint256 i = 0; i < 3; i++) {
            deal(address(erc20Assets[i]), address(this), 1_000_000e18);

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
    }
}
