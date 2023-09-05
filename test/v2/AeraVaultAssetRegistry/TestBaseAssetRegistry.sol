// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@chainlink/interfaces/AggregatorV2V3Interface.sol";
import "@openzeppelin/IERC20.sol";
import "src/v2/interfaces/IAssetRegistry.sol";
import "src/v2/AeraVaultAssetRegistry.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/AeraV2Factory.sol";
import {AssetRegistryParameters, HooksParameters} from "src/v2/Types.sol";
import {TestBaseFactory} from "test/v2/utils/TestBase/TestBaseFactory.sol";
import {ERC20Mock} from "test/utils/ERC20Mock.sol";
import {ERC4626Mock} from "test/utils/ERC4626Mock.sol";
import {IOracleMock, OracleMock} from "test/utils/OracleMock.sol";

contract TestBaseAssetRegistry is TestBaseFactory {
    event Created(
        address indexed owner,
        address indexed vault,
        IAssetRegistry.AssetInformation[] assets,
        uint256 numeraireId,
        address feeToken
    );

    address internal constant _GUARDIAN = address(0x123456);
    address internal constant _FEE_RECIPIENT = address(0x7890ab);
    uint256 internal constant _MAX_FEE = 10 ** 9;

    AeraVaultAssetRegistry public assetRegistry;
    AeraVaultV2 public vault;
    IAssetRegistry.AssetInformation[] public assets;
    IERC20 public feeToken;
    address public numeraireAsset;
    address public nonNumeraireAsset;
    address public nonNumeraireERC4626Asset;
    uint256 public numeraireId;
    uint256 public nonNumeraireId;
    uint256 public nonNumeraireERC4626Id;
    uint256 public numAssets;
    // found by trial and error to make sure sorted numeraire address
    // is before non-numeraire address
    uint256 public numeraireSetIdx = 1;

    function setUp() public virtual override {
        if (_testWithDeployedContracts()) {
            vm.createSelectFork(vm.envString("FORK_URL"));

            factory = AeraV2Factory(_loadDeployedFactory());
            assetRegistry =
                AeraVaultAssetRegistry(_loadDeployedAssetRegistry());
            vault = AeraVaultV2(payable(_loadDeployedVault()));

            vm.prank(assetRegistry.owner());
            assetRegistry.transferOwnership(address(this));

            _loadParameters();
        } else {
            _deploy();
        }
    }

    function propNumeraire() public {
        IAssetRegistry.AssetInformation[] memory registryAssets =
            assetRegistry.assets();

        assertEq(numeraireId, assetRegistry.numeraireId());
        assertEq(numeraireAsset, address(registryAssets[numeraireId].asset));
        assertEq(address(registryAssets[numeraireId].oracle), address(0));
    }

    function propFeeToken() public {
        assertEq(address(feeToken), address(assetRegistry.feeToken()));
    }

    function propNumNonYieldAssets() public {
        IAssetRegistry.AssetInformation[] memory registryAssets =
            assetRegistry.assets();

        uint256 numNonYieldAssets = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            if (!assets[i].isERC4626) {
                numNonYieldAssets++;
            }
        }

        uint256 numRegisteredNonYieldAssets = 0;
        for (uint256 i = 0; i < registryAssets.length; i++) {
            if (!registryAssets[i].isERC4626) {
                numRegisteredNonYieldAssets++;
            }
        }

        assertEq(numNonYieldAssets, numRegisteredNonYieldAssets);
    }

    function propNumYieldAssets() public {
        IAssetRegistry.AssetInformation[] memory registryAssets =
            assetRegistry.assets();

        uint256 numYieldAssets = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i].isERC4626) {
                numYieldAssets++;
            }
        }

        uint256 numRegisteredYieldAssets = 0;
        for (uint256 i = 0; i < registryAssets.length; i++) {
            if (registryAssets[i].isERC4626) {
                numRegisteredYieldAssets++;
            }
        }

        assertEq(numYieldAssets, numRegisteredYieldAssets);
    }

    function propAssetsSorted() internal {
        IAssetRegistry.AssetInformation[] memory registryAssets =
            assetRegistry.assets();

        for (uint256 i = 0; i < registryAssets.length - 1; i++) {
            assertTrue(registryAssets[i].asset < registryAssets[i + 1].asset);
        }
    }

    function propAssets() internal {
        IAssetRegistry.AssetInformation[] memory registryAssets =
            assetRegistry.assets();

        assertEq(numAssets, registryAssets.length);

        for (uint256 i = 0; i < numAssets; i++) {
            assertEq(
                address(registryAssets[i].asset), address(assets[i].asset)
            );
            assertEq(registryAssets[i].isERC4626, assets[i].isERC4626);
            assertEq(
                address(registryAssets[i].oracle), address(assets[i].oracle)
            );
        }
    }

    function _loadDeployedAssetRegistry() internal returns (address) {
        string memory path =
            string.concat(vm.projectRoot(), "/config/Deployments.json");
        string memory json = vm.readFile(path);

        return vm.parseJsonAddress(json, ".assetRegistry");
    }

    function _loadDeployedVault() internal returns (address) {
        string memory path =
            string.concat(vm.projectRoot(), "/config/Deployments.json");
        string memory json = vm.readFile(path);

        return vm.parseJsonAddress(json, ".vault");
    }

    function _loadParameters() internal {
        IAssetRegistry.AssetInformation[] memory registeredAssets =
            assetRegistry.assets();

        numAssets = registeredAssets.length;
        feeToken = assetRegistry.feeToken();
        numeraireId = assetRegistry.numeraireId();
        numeraireAsset = address(registeredAssets[numeraireId].asset);

        for (uint256 i = 0; i < numAssets; i++) {
            assets.push(registeredAssets[i]);

            if (!registeredAssets[i].isERC4626 && i != numeraireId) {
                nonNumeraireId = i;
                nonNumeraireAsset = address(registeredAssets[i].asset);
            }
            if (registeredAssets[i].isERC4626 && i != numeraireId) {
                nonNumeraireERC4626Id = i;
                nonNumeraireERC4626Asset = address(registeredAssets[i].asset);
            }
        }
    }

    function _deploy() internal {
        _deployAeraV2Factory();
        _createAssets(4, 2, 0);

        TargetSighashData[] memory targetSighashAllowlist;

        vm.expectEmit(true, false, false, true);
        emit Created(
            address(this),
            factory.computeVaultAddress(bytes32(0)),
            assets,
            numeraireId,
            address(feeToken)
        );

        (address deployedVault, address deployedAssetRegistry,) = factory
            .create(
            bytes32(0),
            address(this),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault",
            AssetRegistryParameters(
                address(this), assets, numeraireId, feeToken
            ),
            HooksParameters(address(this), 0.1e18, targetSighashAllowlist)
        );

        assetRegistry = AeraVaultAssetRegistry(deployedAssetRegistry);
        vault = AeraVaultV2(payable(deployedVault));
    }

    function _createAssets(
        uint256 numERC20,
        uint256 numERC4626,
        uint256 initalSaltIndex
    ) internal {
        for (uint256 i = 0; i < numERC20; i++) {
            (
                address assetAddress,
                IAssetRegistry.AssetInformation memory asset
            ) =
            // salt value was from trial/error to get desired sorting
             _createAsset(false, address(0), initalSaltIndex + i);

            if (i == numeraireSetIdx) {
                numeraireAsset = address(asset.asset);
                asset.oracle = AggregatorV2V3Interface(address(0));
            } else if (i == (numeraireSetIdx + 1) % numERC20) {
                nonNumeraireAsset = address(asset.asset);
            } else if (i == (numeraireSetIdx + 2) % numERC20) {
                feeToken = asset.asset;
            }

            assets.push(asset);

            if (i < numERC4626) {
                (
                    address asset4626Address,
                    IAssetRegistry.AssetInformation memory asset4626
                ) = _createAsset(
                    true, assetAddress, initalSaltIndex + numERC20 + i
                );
                assets.push(asset4626);
                if (i == 0) {
                    nonNumeraireERC4626Asset = asset4626Address;
                }
            }
        }

        numAssets = numERC20 + numERC4626;

        for (uint256 i = 0; i < numAssets; i++) {
            for (uint256 j = numAssets - 1; j > i; j--) {
                if (assets[j].asset < assets[j - 1].asset) {
                    IAssetRegistry.AssetInformation memory temp = assets[j];
                    assets[j] = assets[j - 1];
                    assets[j - 1] = temp;
                }
            }

            if (address(assets[i].asset) == numeraireAsset) {
                numeraireId = i;
            } else if (address(assets[i].asset) == nonNumeraireAsset) {
                nonNumeraireId = i;
            } else if (address(assets[i].asset) == nonNumeraireERC4626Asset) {
                nonNumeraireERC4626Id = i;
            }
        }
    }

    function _createAsset(
        bool isERC4626,
        address baseAssetAddress,
        uint256 saltIndex
    )
        internal
        returns (
            address asset,
            IAssetRegistry.AssetInformation memory newAsset
        )
    {
        address oracleAddress;

        if (isERC4626) {
            ERC20Mock baseAsset = ERC20Mock(baseAssetAddress);
            asset = address(
                new ERC4626Mock{salt: bytes32(saltIndex)}(
                    baseAsset,
                    baseAsset.name(),
                    baseAsset.symbol()
                )
            );

            oracleAddress = address(0);
        } else {
            asset = address(
                new ERC20Mock{salt: bytes32(saltIndex)}("Token", "TOKEN", 18, 1e30)
            );

            oracleAddress = address(new OracleMock(18));
            IOracleMock(oracleAddress).setLatestAnswer(int256(_ONE));
        }
        newAsset = IAssetRegistry.AssetInformation({
            asset: IERC20(asset),
            isERC4626: isERC4626,
            oracle: AggregatorV2V3Interface(oracleAddress),
            heartbeat: 1 hours
        });
    }
}
