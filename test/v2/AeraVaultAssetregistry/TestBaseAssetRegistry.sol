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
    AeraVaultAssetRegistry internal assetRegistry;
    IAssetRegistry.AssetInformation[] internal assets;
    address internal numeraireAsset;
    uint256 internal numeraire;
    uint256 internal nonNumeraire;
    uint256 internal numAssets;

    function setUp() public virtual{
        for (uint256 i = 0; i < 4; i++) {
            (
                ERC20Mock erc20,
                IAssetRegistry.AssetInformation memory asset
            ) = createAsset();

            if (i == 0) {
                numeraireAsset = address(asset.asset);
                asset.oracle = AggregatorV2V3Interface(address(0));
            }

            assets.push(asset);

            if (i < 2) {
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

        numAssets = assets.length;

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

        assetRegistry = new AeraVaultAssetRegistry(assets, numeraire);
    }

    function createAsset()
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

        IOracleMock(address(newAsset.oracle)).setLatestAnswer(int256(ONE));
    }

    function checkRegisteredAssets() internal {
        uint256 numAssets = assets.length;
        IAssetRegistry.AssetInformation[]
            memory registeredAssets = assetRegistry.getAssets();

        assertEq(numeraire, assetRegistry.numeraire());

        for (uint256 i = 0; i < numAssets; i++) {
            assertEq(
                address(registeredAssets[i].asset),
                address(assets[i].asset)
            );
            assertEq(registeredAssets[i].isERC4626, assets[i].isERC4626);
            assertEq(registeredAssets[i].withdrawable, assets[i].withdrawable);
            assertEq(
                address(registeredAssets[i].oracle),
                address(assets[i].oracle)
            );
        }
    }

    function generateValidWeights()
        internal
        returns (IAssetRegistry.AssetWeight[] memory weights)
    {
        uint256 numAssets = assets.length;

        weights = new IAssetRegistry.AssetWeight[](numAssets);

        uint256 weightSum;
        for (uint256 i = 0; i < numAssets; i++) {
            weights[i] = IAssetRegistry.AssetWeight({
                asset: assets[i].asset,
                weight: ONE / numAssets
            });
            weightSum += ONE / numAssets;
        }

        weights[numAssets - 1].weight += ONE - weightSum;
    }
}
