// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../TestBaseAssetRegistry.sol";

contract AddAssetTest is TestBaseAssetRegistry {
    event AssetAdded(IAssetRegistry.AssetInformation asset);

    IAssetRegistry.AssetInformation newAsset;

    function setUp() public override {
        _deploy();

        (, newAsset) = _createAsset();
    }

    function test_addAsset_fail_whenCallerIsNotOwner() public {
        hoax(USER);

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        assetRegistry.addAsset(newAsset);
    }

    function test_addAsset_fail_whenOracleIsZeroAddress() public {
        newAsset.oracle = AggregatorV2V3Interface(address(0));

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__OracleIsZeroAddress.selector,
                newAsset.asset
            )
        );
        assetRegistry.addAsset(newAsset);
    }

    function test_addAsset_fail_whenAssetIsAlreadyRegistered() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__AssetIsAlreadyRegistered.selector,
                nonNumeraire
            )
        );
        assetRegistry.addAsset(assets[nonNumeraire]);
    }

    function test_addAsset_success() public {
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

        vm.expectEmit(true, true, true, true, address(assetRegistry));
        emit AssetAdded(newAsset);

        assetRegistry.addAsset(newAsset);

        numAssets++;

        propNumeraire();
        propNumYieldAssets();
        propAssets();
    }
}
