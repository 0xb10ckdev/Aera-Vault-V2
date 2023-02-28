// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {TestBase} from "../../utils/TestBase.sol";
import "solmate/tokens/ERC20.sol";
import "../../../src/v2/dependencies/chainlink/interfaces/AggregatorV2V3Interface.sol";
import "../../../src/v2/dependencies/openzeppelin/IERC20.sol";
import "../../../src/v2/interfaces/IAssetRegistry.sol";
import "../../../src/v2/AeraVaultAssetRegistry.sol";
import {ERC20Mock} from "../../utils/ERC20Mock.sol";
import {ERC4626Mock} from "../../utils/ERC4626Mock.sol";
import {IOracleMock, OracleMock} from "../../utils/OracleMock.sol";

contract TestBaseAssetRegistry is TestBase {
    AeraVaultAssetRegistry assetRegistry;
    IAssetRegistry.AssetInformation[] assets;
    address numeraireAsset;
    uint256 numeraire;
    uint256 nonNumeraire;
    uint256 numAssets;

    function setUp() public virtual {
        _deploy();
    }

    function propNumeraire() public {
        IAssetRegistry.AssetInformation[] memory registryAssets = assetRegistry
            .assets();

        assertEq(numeraire, assetRegistry.numeraire());
        assertEq(numeraireAsset, address(registryAssets[numeraire].asset));
        assertEq(address(registryAssets[numeraire].oracle), address(0));
    }

    function propNumYieldAssets() public {
        IAssetRegistry.AssetInformation[] memory registryAssets = assetRegistry
            .assets();

        uint256 numYieldAssets = 0;
        for (uint256 i = 0; i < registryAssets.length; i++) {
            if (registryAssets[i].isERC4626) {
                numYieldAssets++;
            }
        }

        assertEq(numYieldAssets, assetRegistry.numYieldAssets());
    }

    function propAssetsSorted() internal {
        IAssetRegistry.AssetInformation[] memory registryAssets = assetRegistry
            .assets();

        for (uint256 i = 0; i < registryAssets.length - 1; i++) {
            assertTrue(registryAssets[i].asset < registryAssets[i + 1].asset);
        }
    }

    function propAssets() internal {
        IAssetRegistry.AssetInformation[] memory registryAssets = assetRegistry
            .assets();

        assertEq(numAssets, registryAssets.length);

        for (uint256 i = 0; i < numAssets; i++) {
            assertEq(
                address(registryAssets[i].asset),
                address(assets[i].asset)
            );
            assertEq(registryAssets[i].isERC4626, assets[i].isERC4626);
            assertEq(registryAssets[i].withdrawable, assets[i].withdrawable);
            assertEq(
                address(registryAssets[i].oracle),
                address(assets[i].oracle)
            );
        }
    }

    function _deploy() internal {
        _createAssets(4, 2);

        assetRegistry = new AeraVaultAssetRegistry(assets, numeraire);
    }

    function _createAssets(uint256 numERC20, uint256 numERC4626) internal {
        for (uint256 i = 0; i < numERC20; i++) {
            (
                ERC20Mock erc20,
                IAssetRegistry.AssetInformation memory asset
            ) = _createAsset();

            if (i == 0) {
                numeraireAsset = address(asset.asset);
                asset.oracle = AggregatorV2V3Interface(address(0));
            }

            assets.push(asset);

            if (i < numERC4626) {
                ERC4626Mock erc4626 = new ERC4626Mock(
                    erc20,
                    erc20.name(),
                    erc20.symbol()
                );
                assets.push(
                    IAssetRegistry.AssetInformation({
                        asset: IERC20(address(erc4626)),
                        isERC4626: true,
                        withdrawable: true,
                        oracle: AggregatorV2V3Interface(
                            address(new OracleMock(18))
                        )
                    })
                );
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
                numeraire = i;
            }
        }

        nonNumeraire = (numeraire + 1) % numAssets;
    }

    function _createAsset()
        internal
        returns (
            ERC20Mock erc20,
            IAssetRegistry.AssetInformation memory newAsset
        )
    {
        erc20 = new ERC20Mock("Token", "TOKEN", 18, 1e30);
        newAsset = IAssetRegistry.AssetInformation({
            asset: IERC20(address(erc20)),
            isERC4626: false,
            withdrawable: true,
            oracle: AggregatorV2V3Interface(address(new OracleMock(18)))
        });

        IOracleMock(address(newAsset.oracle)).setLatestAnswer(int256(_ONE));
    }

    function _generateValidWeights()
        internal
        returns (IAssetRegistry.AssetWeight[] memory weights)
    {
        IAssetRegistry.AssetInformation[] memory registryAssets = assetRegistry
            .assets();
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
