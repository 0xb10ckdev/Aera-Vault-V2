// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@chainlink/interfaces/AggregatorV2V3Interface.sol";
import "@openzeppelin/IERC20.sol";
import "src/v2/interfaces/IAssetRegistry.sol";
import "src/v2/AeraVaultAssetRegistry.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/AeraVaultV2Factory.sol";
import {TestBaseFactory} from "test/v2/utils/TestBase/TestBaseFactory.sol";
import {ERC20Mock} from "test/utils/ERC20Mock.sol";
import {ERC20MockFactory} from "test/utils/ERC20Mock.sol";
import {ERC4626Mock} from "test/utils/ERC4626Mock.sol";
import {ERC4626MockFactory} from "test/utils/ERC4626Mock.sol";
import {IOracleMock, OracleMock} from "test/utils/OracleMock.sol";

contract TestBaseAssetRegistry is TestBaseFactory {
    event Created(
        address indexed owner,
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

            factory = AeraVaultV2Factory(_loadDeployedFactory());
            assetRegistry =
                AeraVaultAssetRegistry(_loadDeployedAssetRegistry());
            vault = AeraVaultV2(_loadDeployedCustody());

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

    function _loadDeployedCustody() internal returns (address) {
        string memory path =
            string.concat(vm.projectRoot(), "/config/Deployments.json");
        string memory json = vm.readFile(path);

        return vm.parseJsonAddress(json, ".custody");
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
        _deployAeraVaultV2Factory();
        _createAssets(4, 2);

        vm.expectEmit(true, false, false, true);
        emit Created(address(this), assets, numeraireId, address(feeToken));
        assetRegistry = new AeraVaultAssetRegistry(
            address(this),
            assets,
            numeraireId,
            feeToken
        );

        vault = new AeraVaultV2(
            address(this),
            address(assetRegistry),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault"
        );

        assetRegistry.setCustody(address(vault));
    }

    function _createAssets(uint256 numERC20, uint256 numERC4626) internal {
        for (uint256 i = 0; i < numERC20; i++) {
            (
                address assetAddress,
                IAssetRegistry.AssetInformation memory asset
            ) =
            // salt value was from trial/error to get desired sorting
             _createAsset(false, address(0), numERC20 - i);

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
                ) = _createAsset(true, assetAddress, i);
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
        uint256 indexForSalt
    )
        internal
        returns (
            address asset,
            IAssetRegistry.AssetInformation memory newAsset
        )
    {
        address oracleAddress;
        bytes32 salt = bytes32(indexForSalt);
        if (isERC4626) {
            ERC20Mock baseAsset = ERC20Mock(baseAssetAddress);
            asset = ERC4626MockFactory.deploy(
                address(factory),
                baseAsset,
                baseAsset.name(),
                baseAsset.symbol(),
                salt
            );
            oracleAddress = address(0);
        } else {
            asset = ERC20MockFactory.deploy(
                address(factory), "Token", "TOKEN", 18, 1e30, salt
            );
            oracleAddress = address(new OracleMock(18));
            IOracleMock(oracleAddress).setLatestAnswer(int256(_ONE));
        }
        newAsset = IAssetRegistry.AssetInformation({
            asset: IERC20(asset),
            isERC4626: isERC4626,
            oracle: AggregatorV2V3Interface(oracleAddress)
        });
    }

    function _generateValidWeights()
        internal
        view
        returns (IAssetRegistry.AssetWeight[] memory weights)
    {
        IAssetRegistry.AssetInformation[] memory registryAssets =
            assetRegistry.assets();
        weights = new IAssetRegistry.AssetWeight[](numAssets);

        uint256 weightSum;
        for (uint256 i = 0; i < numAssets; i++) {
            weights[i] = IAssetRegistry.AssetWeight({
                asset: registryAssets[i].asset,
                weight: _ONE / numAssets
            });
            weightSum += _ONE / numAssets;
        }

        weights[numAssets - 1].weight += _ONE - weightSum;
    }
}
