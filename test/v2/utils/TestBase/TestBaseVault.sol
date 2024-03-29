// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {stdJson} from "forge-std/Script.sol";
import "@openzeppelin/IERC4626.sol";
import "src/v2/AeraVaultAssetRegistry.sol";
import "src/v2/AeraVaultHooks.sol";
import "src/v2/AeraVaultV2.sol";
import {AssetRegistryParameters, HooksParameters} from "src/v2/Types.sol";
import {TestBaseFactory} from "test/v2/utils/TestBase/TestBaseFactory.sol";
import {TestBaseVariables} from "test/v2/utils/TestBase/TestBaseVariables.sol";
import {ERC20, ERC4626Mock} from "test/utils/ERC4626Mock.sol";

contract TestBaseVault is TestBaseFactory, TestBaseVariables {
    using stdJson for string;

    address internal constant _BTC_USD_ORACLE =
        0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c;
    address internal constant _ETH_USD_ORACLE =
        0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    uint256 internal constant _MAX_FEE = 10 ** 9;
    uint256 internal constant _MIN_DAILY_VALUE = 0.9e18;
    address internal _GUARDIAN = address(0x123456);
    address internal _FEE_RECIPIENT = address(0x7890ab);

    AeraVaultAssetRegistry public assetRegistry;
    AeraVaultHooks public hooks;
    AeraVaultV2 public vault;
    mapping(IERC20 => bool) public isERC4626;
    mapping(IERC20 => uint256) public underlyingIndex;
    IAssetRegistry.AssetInformation[] public assetsInformation;
    IERC20 public numeraireToken;
    IERC20 public feeToken;
    uint256[] public oraclePrices;
    uint256 public nonNumeraireId;
    TargetSighashData[] public targetSighashAllowlist;
    VaultParameters public vaultParameters;
    AssetRegistryParameters public assetRegistryParameters;
    HooksParameters public hooksParameters;

    function setUp() public virtual override {
        if (_testWithDeployedContracts()) {
            vm.createSelectFork(vm.envString("FORK_URL"));
        } else {
            vm.createSelectFork(vm.envString("ETH_NODE_URI_MAINNET"), 17642400);

            _deployAeraV2Factory();

            _init();

            _deployAeraV2Contracts();
        }
    }

    function _updateOwnership() internal {
        if (address(assetRegistry) != address(0)) {
            vm.prank(assetRegistry.owner());
            assetRegistry.transferOwnership(address(this));
        }
        if (address(factory) != address(0)) {
            vm.prank(factory.owner());
            factory.transferOwnership(address(this));
        }
        if (address(vault) != address(0)) {
            vm.prank(vault.owner());
            vault.transferOwnership(address(this));
        }
        if (address(hooks) != address(0)) {
            vm.prank(hooks.owner());
            hooks.transferOwnership(address(this));
        }
    }

    function _loadParameters() internal {
        if (address(vault) != address(0)) {
            _GUARDIAN = vault.guardian();
            _FEE_RECIPIENT = vault.feeRecipient();
        }

        if (address(assetRegistry) != address(0)) {
            feeToken = assetRegistry.feeToken();
            numeraireToken = assetRegistry.numeraireToken();

            IAssetRegistry.AssetInformation[] memory registeredAssets =
                assetRegistry.assets();

            for (uint256 i = 0; i < registeredAssets.length; i++) {
                assetsInformation.push(registeredAssets[i]);
                assets.push(registeredAssets[i].asset);

                deal(address(assets[i]), address(this), 10_000_000e18);
                deal(address(assets[i]), _USER, 10_000_000e18);

                if (registeredAssets[i].isERC4626) {
                    yieldAssets.push(
                        IERC4626(address(registeredAssets[i].asset))
                    );
                } else {
                    erc20Assets.push(registeredAssets[i].asset);

                    if (registeredAssets[i].asset != numeraireToken) {
                        nonNumeraireId = i;
                    }
                }
            }

            _initUnderlyingIndexes();

            for (uint256 i = 0; i < assets.length; i++) {
                uint256 index = i;
                if (assetsInformation[i].isERC4626) {
                    index = underlyingIndex[assets[i]];
                }
                if (assets[i] == numeraireToken) {
                    oraclePrices.push(_getScaler(numeraireToken));
                } else {
                    oraclePrices.push(
                        _getOraclePrice(
                            address(assetsInformation[index].oracle)
                        )
                    );
                }
            }
        }
    }

    function _loadDeployedAddresses()
        internal
        view
        returns (
            address deployedAssetRegistry,
            address deployedFactory,
            address deployedVault,
            address deployedHooks
        )
    {
        string memory path =
            string.concat(vm.projectRoot(), "/config/Deployments.json");
        string memory json = vm.readFile(path);

        try vm.parseJsonAddress(json, ".assetRegistry") returns (address addr)
        {
            deployedAssetRegistry = addr;
        } catch {}
        try vm.parseJsonAddress(json, ".factory") returns (address addr) {
            deployedFactory = addr;
        } catch {}
        try vm.parseJsonAddress(json, ".vault") returns (address addr) {
            deployedVault = addr;
        } catch {}
        try vm.parseJsonAddress(json, ".hooks") returns (address addr) {
            deployedHooks = addr;
        } catch {}
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
                if (address(erc20Assets[erc20Index]) == _WETH_ADDRESS) {
                    nonNumeraireId = i;
                }
                erc20Index++;
            } else {
                assets.push(yieldAssets[erc4626Index]);
                erc4626Index++;
            }
        }

        _initUnderlyingIndexes();

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
                        ),
                    heartbeat: 1 hours
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
        numeraireToken = IERC20(_USDC_ADDRESS);

        vaultParameters.owner = address(this);
        vaultParameters.guardian = _GUARDIAN;
        vaultParameters.feeRecipient = _FEE_RECIPIENT;
        vaultParameters.fee = _MAX_FEE;

        assetRegistryParameters.factory = address(modulesFactory);
        assetRegistryParameters.owner = address(this);
        assetRegistryParameters.assets = assetsInformation;
        assetRegistryParameters.numeraireToken = numeraireToken;
        assetRegistryParameters.feeToken = feeToken;

        hooksParameters.factory = address(modulesFactory);
        hooksParameters.owner = address(this);
        hooksParameters.minDailyValue = _MIN_DAILY_VALUE;
        hooksParameters.targetSighashAllowlist = targetSighashAllowlist;
    }

    function _initUnderlyingIndexes() internal {
        for (uint256 i = 0; i < yieldAssets.length; i++) {
            isERC4626[yieldAssets[i]] = true;
            for (uint256 j = 0; j < assets.length; j++) {
                if (yieldAssets[i].asset() == address(assets[j])) {
                    underlyingIndex[yieldAssets[i]] = j;
                    break;
                }
            }
        }
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

    function _deployAeraV2Contracts() internal {
        (
            address deployedVault,
            address deployedAssetRegistry,
            address deployedHooks
        ) = factory.create(
            bytes32(0),
            "Test Vault",
            vaultParameters,
            assetRegistryParameters,
            hooksParameters
        );

        assetRegistry = AeraVaultAssetRegistry(deployedAssetRegistry);
        vault = AeraVaultV2(payable(deployedVault));
        hooks = AeraVaultHooks(deployedHooks);
    }

    function _getOraclePrice(address oracle) internal view returns (uint256) {
        return uint256(AggregatorV2V3Interface(oracle).latestAnswer()) * 1e6
            / 10 ** AggregatorV2V3Interface(oracle).decimals();
    }

    function _getScaler(IERC20 token) internal view returns (uint256) {
        return 10 ** IERC20Metadata(address(token)).decimals();
    }
}
