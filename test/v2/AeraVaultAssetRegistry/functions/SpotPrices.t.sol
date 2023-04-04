// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAssetRegistry.sol";

contract SpotPricesTest is TestBaseAssetRegistry {
    function test_spotPrices_fail_whenOraclePriceIsInvalid() public {
        for (uint256 i = 0; i < numAssets; i++) {
            if (i != numeraire && !assets[i].isERC4626) {
                nonNumeraire = i;
                break;
            }
        }

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

    function test_spotPrices_success() public {
        uint256 testPrice = _ONE * 5;

        for (uint256 i = 0; i < numAssets; i++) {
            if (i == numeraire || assets[i].isERC4626) {
                continue;
            }
            IOracleMock(address(assets[i].oracle)).setLatestAnswer(
                int256(testPrice)
            );
        }

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
                assertEq(spotPrices[index].spotPrice, _ONE);
            } else {
                uint256 oracleUnit = 10**assets[i].oracle.decimals();
                uint256 price = (testPrice * _ONE) / oracleUnit;

                assertEq(spotPrices[index].spotPrice, price);
            }

            index++;
        }
    }
}
