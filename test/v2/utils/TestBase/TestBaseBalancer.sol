// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/IERC4626.sol";
import "src/v2/interfaces/IBalancerExecution.sol";
import "src/v2/AeraBalancerExecution.sol";
import "src/v2/AeraVaultAssetRegistry.sol";
import {IAsset} from
    "src/v2/dependencies/balancer-labs/interfaces/contracts/vault/IAsset.sol";
import {IManagedPool} from
    "src/v2/dependencies/balancer-labs/interfaces/contracts/pool-utils/IManagedPool.sol";
import {IVault} from
    "src/v2/dependencies/balancer-labs/interfaces/contracts/vault/IVault.sol";
import {Deployer} from "test/utils/Deployer.sol";
import {TestBase} from "test/utils/TestBase.sol";
import {TestBaseVariables} from "test/v2/utils/TestBase/TestBaseVariables.sol";
import {ERC20Mock} from "test/utils/ERC20Mock.sol";
import {ERC20, ERC4626Mock} from "test/utils/ERC4626Mock.sol";
import {IOracleMock, OracleMock} from "test/utils/OracleMock.sol";

contract TestBaseBalancer is TestBase, TestBaseVariables, Deployer {
    address internal _WBTC_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal _USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal _WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal _BVAULT_ADDRESS =
        0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address internal _MERKLE_ORCHARDS =
        0xdAE7e32ADc5d490a43cCba1f0c736033F2b4eFca;
    address internal _GUARDIAN = address(0x123456);
    address internal _FEE_RECIPIENT = address(0x7890ab);
    uint256 internal _MAX_GUARDIAN_FEE = 10 ** 9;
    uint256 internal _MAX_SWAP_RATIO = 0.3e18;

    AeraBalancerExecution balancerExecution;
    AeraVaultAssetRegistry assetRegistry;
    address balancerManagedPoolFactory;
    mapping(IERC20 => bool) isERC4626;
    mapping(IERC20 => uint256) underlyingIndex;
    IAssetRegistry.AssetInformation[] assetsInformation;
    IERC20 feeToken;
    uint256[] oraclePrices;
    uint256 numeraire;
    uint256 nonNumeraire;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_NODE_URI_MAINNET"), 16826100);

        _init();

        _deployAssetRegistry();
        _deployBalancerManagedPoolFactory();
        _deployBalancerExecution();
    }

    function _init() internal {
        _deployYieldAssets();

        erc20Assets.push(IERC20(_WBTC_ADDRESS));
        erc20Assets.push(IERC20(_USDC_ADDRESS));
        erc20Assets.push(IERC20(_WETH_ADDRESS));

        uint256 numERC20 = erc20Assets.length;
        uint256 numERC4626 = yieldAssets.length;
        uint256 erc20Index = 0;
        uint256 erc4626Index = 0;

        for (uint256 i = 0; i < numERC20 + numERC4626; i++) {
            if (
                erc4626Index == numERC4626
                    || (
                        erc20Index < numERC20
                            && address(erc20Assets[erc20Index])
                                < address(yieldAssets[erc4626Index])
                    )
            ) {
                assets.push(erc20Assets[erc20Index]);
                if (address(erc20Assets[erc20Index]) == _USDC_ADDRESS) {
                    numeraire = i;
                } else if (address(erc20Assets[erc20Index]) == _WETH_ADDRESS) {
                    nonNumeraire = i;
                }
                erc20Index++;
            } else {
                assets.push(yieldAssets[erc4626Index]);
                erc4626Index++;
            }
        }

        for (uint256 i = 0; i < yieldAssets.length; i++) {
            isERC4626[yieldAssets[i]] = true;
            for (uint256 j = 0; j < assets.length; j++) {
                if (yieldAssets[i].asset() == address(assets[j])) {
                    underlyingIndex[yieldAssets[i]] = j;
                    break;
                }
            }
        }

        for (uint256 i = 0; i < assets.length; i++) {
            if (!isERC4626[assets[i]]) {
                deal(address(assets[i]), address(this), 10_000_000e18);
                deal(address(assets[i]), _USER, 10_000_000e18);
            }
            assetsInformation.push(
                IAssetRegistry.AssetInformation({
                    asset: assets[i],
                    isERC4626: isERC4626[assets[i]],
                    oracle: AggregatorV2V3Interface(
                        i == numeraire || isERC4626[assets[i]]
                            ? address(0)
                            : address(new OracleMock(6))
                        )
                })
            );
        }

        for (uint256 i = 0; i < yieldAssets.length; i++) {
            IERC20(yieldAssets[i].asset()).approve(
                address(yieldAssets[i]), type(uint256).max
            );
            yieldAssets[i].deposit(1_000_000e18, address(this));
        }

        for (uint256 i = 0; i < assets.length; i++) {
            if (assetsInformation[i].isERC4626) {
                if (
                    IERC4626(address(assetsInformation[i].asset)).asset()
                        == _WBTC_ADDRESS
                ) {
                    oraclePrices.push(15_000e6);
                } else if (
                    IERC4626(address(assetsInformation[i].asset)).asset()
                        == _WETH_ADDRESS
                ) {
                    oraclePrices.push(1_000e6);
                } else {
                    oraclePrices.push(1e6);
                }
            } else {
                if (address(assetsInformation[i].asset) == _WBTC_ADDRESS) {
                    oraclePrices.push(15_000e6);
                    IOracleMock(address(assetsInformation[i].oracle))
                        .setLatestAnswer(int256(oraclePrices[i]));
                } else if (
                    address(assetsInformation[i].asset) == _WETH_ADDRESS
                ) {
                    oraclePrices.push(1_000e6);
                    IOracleMock(address(assetsInformation[i].oracle))
                        .setLatestAnswer(int256(oraclePrices[i]));
                } else {
                    oraclePrices.push(1e6);
                }
            }
        }

        feeToken = IERC20(_USDC_ADDRESS);
    }

    function _deployYieldAssets() internal {
        ERC4626Mock[] memory erc4626Mocks = new ERC4626Mock[](2);

        erc4626Mocks[0] = new ERC4626Mock(
            ERC20(_WBTC_ADDRESS),
            "aWBTC",
            "AWBTC"
        );
        erc4626Mocks[1] = new ERC4626Mock(
            ERC20(_USDC_ADDRESS),
            "aUSDC",
            "AUSDC"
        );

        if (address(erc4626Mocks[0]) < address(erc4626Mocks[1])) {
            yieldAssets.push(IERC4626(address(erc4626Mocks[0])));
            yieldAssets.push(IERC4626(address(erc4626Mocks[1])));
        } else {
            yieldAssets.push(IERC4626(address(erc4626Mocks[1])));
            yieldAssets.push(IERC4626(address(erc4626Mocks[0])));
        }
    }

    function _deployAssetRegistry() internal {
        assetRegistry = new AeraVaultAssetRegistry(
            assetsInformation,
            numeraire,
            feeToken
        );
    }

    function _deployBalancerManagedPoolFactory() internal {
        address managedPoolAddRemoveTokenLib =
            deploy("ManagedPoolAddRemoveTokenLib.sol");

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
        view
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
            merkleOrchard: _MERKLE_ORCHARDS,
            description: "Test Execution"
        });
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
                    uint256 necessaryAmount =
                        targetAmounts[i] - holdings[i].value;
                    IVault(_BVAULT_ADDRESS).swap(
                        IVault.SingleSwap({
                            poolId: balancerExecution.poolId(),
                            kind: IVault.SwapKind.GIVEN_IN,
                            assetIn: IAsset(address(erc20Assets[i])),
                            assetOut: IAsset(address(erc20Assets[i + 1])),
                            amount: necessaryAmount
                                < (holdings[i].value * _MAX_SWAP_RATIO) / _ONE
                                ? necessaryAmount
                                : (holdings[i].value * _MAX_SWAP_RATIO) / _ONE,
                            userData: "0x"
                        }),
                        fundManagement,
                        0,
                        block.timestamp + 100
                    );
                } else if (holdings[i].value > targetAmounts[i]) {
                    uint256 necessaryAmount =
                        holdings[i].value - targetAmounts[i];
                    IVault(_BVAULT_ADDRESS).swap(
                        IVault.SingleSwap({
                            poolId: balancerExecution.poolId(),
                            kind: IVault.SwapKind.GIVEN_OUT,
                            assetIn: IAsset(address(erc20Assets[i + 1])),
                            assetOut: IAsset(address(erc20Assets[i])),
                            amount: necessaryAmount
                                < (holdings[i].value * _MAX_SWAP_RATIO) / _ONE
                                ? necessaryAmount
                                : (holdings[i].value * _MAX_SWAP_RATIO) / _ONE,
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
        view
        returns (uint256[] memory targetAmounts)
    {
        IERC20[] memory poolTokens = balancerExecution.assets();
        IExecution.AssetValue[] memory holdings = balancerExecution.holdings();
        IAssetRegistry.AssetPriceReading[] memory spotPrices =
            assetRegistry.spotPrices();
        uint256[] memory values = new uint256[](poolTokens.length);
        uint256 totalValue;

        for (uint256 i = 0; i < poolTokens.length; i++) {
            for (uint256 j = 0; j < spotPrices.length; j++) {
                if (poolTokens[i] == spotPrices[j].asset) {
                    values[i] = (holdings[i].value * spotPrices[j].spotPrice)
                        / _getScaler(poolTokens[i]);
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
                    targetAmounts[i] = (
                        (totalValue * poolWeights[i])
                            * _getScaler(poolTokens[i])
                    ) / _ONE / spotPrices[j].spotPrice;

                    break;
                }
            }
        }
    }

    function _getScaler(IERC20 token) internal view returns (uint256) {
        return 10 ** IERC20Metadata(address(token)).decimals();
    }
}
