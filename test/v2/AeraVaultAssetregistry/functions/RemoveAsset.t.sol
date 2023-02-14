// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../TestBaseAssetRegistry.sol";

contract RemoveAssetTest is TestBaseAssetRegistry {
    event AssetRemoved(address asset);

    function test_removeAsset_fail_whenCallerIsNotOwner() public {
        hoax(USER);

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        assetRegistry.removeAsset(address(assets[nonNumeraire].asset));
    }

    function test_removeAsset_fail_whenRemovalAssetIsNumeraireAsset() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry
                    .Aera__CannotRemoveNumeraireAsset
                    .selector,
                assets[numeraire].asset
            )
        );
        assetRegistry.removeAsset(address(assets[numeraire].asset));
    }

    function test_removeAsset_fail_whenAssetIsNotRegistered() public {
        (ERC20Mock erc20, ) = _createAsset();

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__AssetNotRegistered.selector,
                erc20
            )
        );
        assetRegistry.removeAsset(address(erc20));
    }

    function test_removeAsset_success() public {
        IAssetRegistry.AssetInformation[] memory registryAssets = assetRegistry
            .assets();
        address removalAsset = address(registryAssets[nonNumeraire].asset);

        vm.expectEmit(true, true, true, true, address(assetRegistry));
        emit AssetRemoved(removalAsset);

        assetRegistry.removeAsset(removalAsset);

        registryAssets = assetRegistry.assets();

        for (uint256 i = 0; i < registryAssets.length; i++) {
            assertTrue(removalAsset != address(registryAssets[i].asset));
        }

        if (nonNumeraire < numeraire) {
            numeraire--;
        }

        for (uint256 i = nonNumeraire; i < numAssets - 1; i++) {
            assets[i] = assets[i + 1];
        }

        assets.pop();

        numAssets--;

        propNumeraire();
        propNumYieldAssets();
        propAssets();
    }
}
