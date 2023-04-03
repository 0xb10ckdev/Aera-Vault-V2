// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "../TestBaseAssetRegistry.sol";

contract RemoveAssetTest is TestBaseAssetRegistry {
    event AssetRemoved(address asset);

    function test_removeAsset_fail_whenCallerIsNotOwner() public {
        hoax(_USER);

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
        uint256 numRegistryAssets = assetRegistry.assets().length;
        IERC20 removalAsset = assets[nonNumeraire].asset;

        vm.expectEmit(true, true, true, true, address(assetRegistry));
        emit AssetRemoved(address(removalAsset));

        assetRegistry.removeAsset(address(removalAsset));

        IAssetRegistry.AssetInformation[] memory updatedAssets = assetRegistry
            .assets();

        bool exist;
        for (uint256 i = 0; i < numAssets; i++) {
            if (removalAsset == assets[i].asset) {
                continue;
            }

            exist = false;
            for (uint256 j = 0; j < updatedAssets.length; j++) {
                if (assets[i].asset == updatedAssets[j].asset) {
                    exist = true;
                    break;
                }
            }
            assertTrue(exist);
        }

        for (uint256 i = 0; i < updatedAssets.length; i++) {
            assertTrue(removalAsset != updatedAssets[i].asset);
        }

        assertEq(numRegistryAssets - 1, updatedAssets.length);

        if (removalAsset < assets[numeraire].asset) {
            numeraire++;
        }

        propNumeraire();
        propNumYieldAssets();
        propAssetsSorted();
    }
}
