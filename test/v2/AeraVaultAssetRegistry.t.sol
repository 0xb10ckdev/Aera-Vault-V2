// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "solmate/tokens/ERC20.sol";
import "../../src/v2/dependencies/chainlink/interfaces/AggregatorV2V3Interface.sol";
import "../../src/v2/dependencies/openzeppelin/IERC20.sol";
import "../../src/v2/interfaces/IAssetRegistry.sol";
import "../../src/v2/AeraVaultAssetRegistry.sol";
import {ERC20Mock} from "../utils/ERC20Mock.sol";
import {ERC4626Mock} from "../utils/ERC4626Mock.sol";
import {IOracleMock, OracleMock} from "../utils/OracleMock.sol";

contract AeraVaultAssetRegistryTest is Test {
    uint256 internal constant ONE = 1e18;
    address internal constant USER = address(0xabcdef);

    AeraVaultAssetRegistry internal assetRegistry;
    IAssetRegistry.AssetInformation[] internal assets;
    address internal numeraireAsset;
    uint256 internal numeraire;

    function setUp() public {
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

        for (uint256 i = 0; i < assets.length; i++) {
            for (uint256 j = assets.length - 1; j > i; j--) {
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

    function test_revert_deployment() public {
        uint256 numAssets = assets.length;
        uint256 nonNumeraire = (numeraire + 1) % numAssets;

        // when numeraire index exceeds asset length
        uint256 invalidNumeraire = numAssets + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry
                    .Aera__NumeraireAssetIndexExceedsAssetLength
                    .selector,
                numAssets,
                invalidNumeraire
            )
        );
        new AeraVaultAssetRegistry(assets, invalidNumeraire);

        // when asset order is incorrect
        IAssetRegistry.AssetInformation[] memory invalidAssets = assets;
        invalidAssets[0] = assets[1];
        invalidAssets[1] = assets[0];
        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__AssetOrderIsIncorrect.selector,
                0
            )
        );
        new AeraVaultAssetRegistry(invalidAssets, numeraire);

        // when numeraire oracle is not zero address
        invalidAssets = assets;
        invalidAssets[numeraire].oracle = AggregatorV2V3Interface(address(1));
        vm.expectRevert(
            AeraVaultAssetRegistry
                .Aera__NumeraireOracleIsNotZeroAddress
                .selector
        );
        new AeraVaultAssetRegistry(invalidAssets, numeraire);

        // when non-numeraire oracle is zero address
        invalidAssets = assets;
        invalidAssets[nonNumeraire].oracle = AggregatorV2V3Interface(
            address(0)
        );
        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__OracleIsZeroAddress.selector,
                assets[nonNumeraire].asset
            )
        );
        new AeraVaultAssetRegistry(invalidAssets, numeraire);
    }

    function test_deployment() public {
        checkRegisteredAssets();
    }

    function test_revert_addAsset() public {
        uint256 numAssets = assets.length;
        uint256 nonNumeraire = (numeraire + 1) % numAssets;

        (, IAssetRegistry.AssetInformation memory newAsset) = createAsset();

        // when caller is non-owner
        hoax(USER);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        assetRegistry.addAsset(newAsset);

        // when oracle is zero address
        IAssetRegistry.AssetInformation memory invalidAsset = newAsset;
        invalidAsset.oracle = AggregatorV2V3Interface(address(0));
        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__OracleIsZeroAddress.selector,
                invalidAsset.asset
            )
        );
        assetRegistry.addAsset(invalidAsset);

        // when asset is already registered
        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__AssetIsAlreadyRegistered.selector,
                nonNumeraire
            )
        );
        assetRegistry.addAsset(assets[nonNumeraire]);
    }

    function test_addAsset() public {
        uint256 numAssets = assets.length;

        (, IAssetRegistry.AssetInformation memory newAsset) = createAsset();

        uint256 newAssetIndex = numAssets;
        for (uint256 i = 0; i < numAssets; i++) {
            if (newAsset.asset < assets[i].asset) {
                newAssetIndex = i;
                if (newAssetIndex <= numeraire) {
                    numeraire++;
                }
                break;
            }
        }

        if (newAssetIndex == numAssets) {
            assets.push(newAsset);
        } else {
            assets.push(assets[numAssets - 1]);

            for (uint256 i = numAssets - 1; i > newAssetIndex; i--) {
                assets[i] = assets[i - 1];
            }

            assets[newAssetIndex] = newAsset;
        }

        assetRegistry.addAsset(newAsset);

        checkRegisteredAssets();
    }

    function test_revert_removeAsset() public {
        uint256 numAssets = assets.length;
        uint256 nonNumeraire = (numeraire + 1) % numAssets;

        // when caller is non-owner
        hoax(USER);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        assetRegistry.removeAsset(address(assets[nonNumeraire].asset));

        // when removal asset is numeraire asset
        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry
                    .Aera__CannotRemoveNumeraireAsset
                    .selector,
                assets[numeraire].asset
            )
        );
        assetRegistry.removeAsset(address(assets[numeraire].asset));

        // when asset is not registered
        (ERC20Mock erc20, ) = createAsset();
        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__NoAssetIsRegistered.selector,
                erc20
            )
        );
        assetRegistry.removeAsset(address(erc20));
    }

    function test_removeAsset() public {
        uint256 numAssets = assets.length;
        uint256 nonNumeraire = (numeraire + 1) % numAssets;

        assetRegistry.removeAsset(address(assets[nonNumeraire].asset));

        for (uint256 i = nonNumeraire; i < numAssets - 1; i++) {
            assets[i] = assets[i + 1];
        }

        delete assets[numAssets - 1];

        checkRegisteredAssets();
    }

    function test_revert_checkWeights() public {
        uint256 numAssets = assets.length;
        IAssetRegistry.AssetWeight[] memory weights = generateValidWeights();

        // when number of current weights and assets doesn't match
        IAssetRegistry.AssetWeight[]
            memory invalidCurrentWeights = new IAssetRegistry.AssetWeight[](
                numAssets + 1
            );
        for (uint256 i = 0; i < numAssets; i++) {
            invalidCurrentWeights[i] = weights[i];
        }
        invalidCurrentWeights[numAssets] = weights[0];
        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__ValueLengthIsNotSame.selector,
                numAssets,
                invalidCurrentWeights.length
            )
        );
        assetRegistry.checkWeights(invalidCurrentWeights, weights);

        // when number of target weights and assets doesn't match
        IAssetRegistry.AssetWeight[]
            memory invalidTargetWeights = new IAssetRegistry.AssetWeight[](
                numAssets - 1
            );
        for (uint256 i = 0; i < numAssets - 1; i++) {
            invalidTargetWeights[i] = weights[i];
        }
        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__ValueLengthIsNotSame.selector,
                numAssets,
                invalidTargetWeights.length
            )
        );
        assetRegistry.checkWeights(weights, invalidTargetWeights);

        // when sum of target weights is not one
        invalidTargetWeights = weights;
        invalidTargetWeights[0].weight += 1;
        vm.expectRevert(
            AeraVaultAssetRegistry.Aera__SumOfWeightIsNotOne.selector
        );
        assetRegistry.checkWeights(weights, invalidTargetWeights);
    }

    function test_checkWeights() public {
        IAssetRegistry.AssetWeight[]
            memory currentWeights = generateValidWeights();
        IAssetRegistry.AssetWeight[]
            memory targetWeights = generateValidWeights();

        assertTrue(assetRegistry.checkWeights(currentWeights, targetWeights));
    }

    function test_revert_spotPrices() public {
        uint256 numAssets = assets.length;
        uint256 nonNumeraire;
        for (uint256 i = 0; i < numAssets; i++) {
            if (i != numeraire && !assets[i].isERC4626) {
                nonNumeraire = i;
                break;
            }
        }

        // when oracle price is invalid
        IOracleMock(address(assets[nonNumeraire].oracle)).setLatestAnswer(0);
        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__OraclePriceIsInvalid.selector,
                nonNumeraire,
                0
            )
        );
        assetRegistry.spotPrices();
    }

    function test_spotPrices() public {
        uint256 numAssets = assets.length;
        IAssetRegistry.AssetPriceReading[] memory spotPrices = assetRegistry
            .spotPrices();

        uint256 index;
        for (uint256 i = 0; i < numAssets; i++) {
            if (assets[i].isERC4626) {
                continue;
            }

            assertEq(
                address(spotPrices[index].asset),
                address(assets[i].asset)
            );

            if (i == numeraire) {
                assertEq(spotPrices[index].spotPrice, ONE);
            } else {
                (, int256 answer, , , ) = assets[i].oracle.latestRoundData();
                uint256 oracleUnit = 10**assets[i].oracle.decimals();
                uint256 price = (uint256(answer) * ONE) / oracleUnit;

                assertEq(spotPrices[index].spotPrice, price);
            }

            index++;
        }
    }
}
