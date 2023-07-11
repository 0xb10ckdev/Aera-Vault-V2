// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAssetRegistry.sol";

contract RemoveAssetTest is TestBaseAssetRegistry {
    event AssetRemoved(address asset);

    function test_removeAsset_fail_whenCallerIsNotOwner() public {
        hoax(_USER);

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        assetRegistry.removeAsset(address(assets[nonNumeraireId].asset));
    }

    function test_removeAsset_fail_whenRemovalAssetIsNumeraireAsset() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry
                    .Aera__CannotRemoveNumeraireAsset
                    .selector,
                assets[numeraireId].asset
            )
        );
        assetRegistry.removeAsset(address(assets[numeraireId].asset));
    }

    function test_removeAsset_fail_whenRemovalAssetIsFeeToken() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__CannotRemoveFeeToken.selector,
                feeToken
            )
        );
        assetRegistry.removeAsset(address(feeToken));
    }

    function test_removeAsset_fail_whenAssetIsNotRegistered() public {
        (ERC20Mock erc20,) = _createAsset();

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__AssetNotRegistered.selector, erc20
            )
        );
        assetRegistry.removeAsset(address(erc20));
    }

    function test_removeAsset_success() public {
        uint256 numRegistryAssets = assetRegistry.assets().length;
        IERC20 removalAsset = assets[nonNumeraireId].asset;

        vm.expectEmit(true, true, true, true, address(assetRegistry));
        emit AssetRemoved(address(removalAsset));

        assetRegistry.removeAsset(address(removalAsset));

        IAssetRegistry.AssetInformation[] memory updatedAssets =
            assetRegistry.assets();

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

        if (removalAsset < assets[numeraireId].asset) {
            numeraireId++;
        }

        propNumeraire();
        propFeeToken();
        propNumYieldAssets();
        propAssetsSorted();
    }
}
