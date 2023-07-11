// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAssetRegistry.sol";

contract AddAssetTest is TestBaseAssetRegistry {
    event AssetAdded(IAssetRegistry.AssetInformation asset);

    IAssetRegistry.AssetInformation newAsset;

    function setUp() public override {
        _deploy();

        (, newAsset) = _createAsset();
    }

    function test_addAsset_fail_whenCallerIsNotOwner() public {
        hoax(_USER);

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
                nonNumeraireId
            )
        );
        assetRegistry.addAsset(assets[nonNumeraireId]);
    }

    function test_addAsset_success() public {
        uint256 numRegistryAssets = assetRegistry.assets().length;

        vm.expectEmit(true, true, true, true, address(assetRegistry));
        emit AssetAdded(newAsset);

        assetRegistry.addAsset(newAsset);

        IAssetRegistry.AssetInformation[] memory updatedAssets =
            assetRegistry.assets();

        bool exist;
        for (uint256 i = 0; i < numAssets; i++) {
            exist = false;
            for (uint256 j = 0; j < updatedAssets.length; j++) {
                if (assets[i].asset == updatedAssets[j].asset) {
                    exist = true;
                    break;
                }
            }
            assertTrue(exist);
        }

        exist = false;
        for (uint256 i = 0; i < updatedAssets.length; i++) {
            if (newAsset.asset == updatedAssets[i].asset) {
                exist = true;
                break;
            }
        }
        assertTrue(exist);

        assertEq(numRegistryAssets + 1, updatedAssets.length);

        if (newAsset.asset < assets[numeraireId].asset) {
            numeraireId++;
        }

        propNumeraire();
        propFeeToken();
        propNumYieldAssets();
        propAssetsSorted();
    }
}
