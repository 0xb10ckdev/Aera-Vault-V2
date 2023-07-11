// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/IERC4626.sol";
import "src/v2/AeraVaultAssetRegistry.sol";
import "src/v2/AeraVaultHooks.sol";
import "src/v2/AeraVaultV2.sol";
import {Deployer} from "test/utils/Deployer.sol";
import {TestBase} from "test/utils/TestBase.sol";
import {TestBaseVariables} from "test/v2/utils/TestBase/TestBaseVariables.sol";
import {ERC20Mock} from "test/utils/ERC20Mock.sol";
import {ERC20, ERC4626Mock} from "test/utils/ERC4626Mock.sol";
import {IOracleMock, OracleMock} from "test/utils/OracleMock.sol";

contract TestBaseCustody is TestBase, TestBaseVariables, Deployer {
    address internal _WBTC_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal _USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal _WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal _BTC_USD_ORACLE =
        0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    address internal _ETH_USD_ORACLE =
        0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address internal _GUARDIAN = address(0x123456);
    address internal _FEE_RECIPIENT = address(0x7890ab);
    uint256 internal _MAX_FEE = 10 ** 9;
    uint256 internal _MAX_DAILY_EXECUTION_LOSS = 0.1e18;

    AeraVaultAssetRegistry assetRegistry;
    AeraVaultHooks hooks;
    AeraVaultV2 vault;
    mapping(IERC20 => bool) isERC4626;
    mapping(IERC20 => uint256) underlyingIndex;
    IAssetRegistry.AssetInformation[] assetsInformation;
    IERC20 feeToken;
    uint256[] oraclePrices;
    uint256 numeraireId;
    uint256 nonNumeraireId;
    TargetSighash[] targetSighashAllowlist;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_NODE_URI_MAINNET"), 17642400);

        _init();

        _deployAssetRegistry();
        _deployAeraVaultV2();
        _deployHooks();
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
                    numeraireId = i;
                } else if (address(erc20Assets[erc20Index]) == _WETH_ADDRESS) {
                    nonNumeraireId = i;
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
                        address(assets[i]) == _WBTC_ADDRESS
                            ? _BTC_USD_ORACLE
                            : address(assets[i]) == _WETH_ADDRESS
                                ? _ETH_USD_ORACLE
                                : address(0)
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
                    oraclePrices.push(_getOraclePrice(_BTC_USD_ORACLE));
                } else if (
                    IERC4626(address(assetsInformation[i].asset)).asset()
                        == _WETH_ADDRESS
                ) {
                    oraclePrices.push(_getOraclePrice(_ETH_USD_ORACLE));
                } else {
                    oraclePrices.push(1e6);
                }
            } else {
                if (address(assetsInformation[i].asset) == _WBTC_ADDRESS) {
                    oraclePrices.push(_getOraclePrice(_BTC_USD_ORACLE));
                } else if (
                    address(assetsInformation[i].asset) == _WETH_ADDRESS
                ) {
                    oraclePrices.push(_getOraclePrice(_ETH_USD_ORACLE));
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
            numeraireId,
            feeToken
        );
    }

    function _deployHooks() internal {
        hooks = new AeraVaultHooks(
            address(vault),
            _MAX_DAILY_EXECUTION_LOSS,
            targetSighashAllowlist
        );

        vault.setHooks(address(hooks));
    }

    function _deployAeraVaultV2() internal {
        vault = new AeraVaultV2(
            address(assetRegistry),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE
        );
    }

    function _getOraclePrice(address oracle) internal view returns (uint256) {
        return uint256(AggregatorV2V3Interface(oracle).latestAnswer()) * 1e6
            / 10 ** AggregatorV2V3Interface(oracle).decimals();
    }

    function _getScaler(IERC20 token) internal view returns (uint256) {
        return 10 ** IERC20Metadata(address(token)).decimals();
    }
}
