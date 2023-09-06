// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAssetRegistry.sol";

contract SpotPricesTest is TestBaseAssetRegistry {
    function test_spotPrices_fail_whenSequencerIsDown() public {
        assetRegistry = new AeraVaultAssetRegistry(
            address(this),
            address(vault),
            assets,
            numeraireId,
            feeToken,
            AggregatorV2V3Interface(address(new OracleMock(18)))
        );
        OracleMock(address(assetRegistry.sequencer())).setLatestAnswer(1);

        vm.expectRevert(AeraVaultAssetRegistry.Aera__SequencerIsDown.selector);
        assetRegistry.spotPrices();
    }

    function test_spotPrices_fail_whenOraclePriceIsInvalid() public {
        deployCodeTo(
            "OracleMock.sol",
            abi.encode(6),
            address(assets[nonNumeraireId].oracle)
        );
        OracleMock(address(assets[nonNumeraireId].oracle)).setLatestAnswer(0);

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__OraclePriceIsInvalid.selector,
                nonNumeraireId,
                0
            )
        );
        assetRegistry.spotPrices();
    }

    function test_spotPrices_fail_whenOraclePriceIsTooOld() public {
        skip(assets[nonNumeraireId].heartbeat + 1 hours + 1);

        for (uint256 i = 0; i < numAssets; i++) {
            if (address(assets[i].oracle) != address(0) && i != nonNumeraireId)
            {
                OracleMock(address(assets[i].oracle)).setUpdatedAt(
                    block.timestamp
                );
            }
        }

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__OraclePriceIsTooOld.selector,
                nonNumeraireId,
                OracleMock(address(assets[nonNumeraireId].oracle)).updatedAt()
            )
        );
        assetRegistry.spotPrices();
    }

    function test_spotPrices_success() public {
        uint256 testPrice = _ONE * 5;

        for (uint256 i = 0; i < numAssets; i++) {
            if (i == numeraireId || assets[i].isERC4626) {
                continue;
            }

            deployCodeTo(
                "OracleMock.sol", abi.encode(6), address(assets[i].oracle)
            );
            IOracleMock(address(assets[i].oracle)).setLatestAnswer(
                int256(testPrice)
            );
        }

        IAssetRegistry.AssetPriceReading[] memory spotPrices =
            assetRegistry.spotPrices();

        uint256 numeraireUnit = 10 ** IERC20Metadata(numeraireAsset).decimals();

        uint256 index;
        for (uint256 i = 0; i < numAssets; i++) {
            if (assets[i].isERC4626) {
                continue;
            }

            assertEq(
                address(spotPrices[index].asset), address(assets[i].asset)
            );

            if (i == numeraireId) {
                assertEq(spotPrices[index].spotPrice, numeraireUnit);
            } else {
                uint256 oracleUnit = 10 ** assets[i].oracle.decimals();
                uint256 price = (testPrice * numeraireUnit) / oracleUnit;

                assertEq(spotPrices[index].spotPrice, price);
            }

            index++;
        }
    }
}
