// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAssetRegistry.sol";

contract RemoveAssetTest is TestBaseAssetRegistry {
    event AssetRemoved(address asset);

    function test_removeAsset_fail_whenCallerIsNotOwner() public {
        hoax(_USER);

        vm.expectRevert("Ownable: caller is not the owner");
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
        if (address(feeToken) == numeraireAsset) {
            vm.expectRevert(
                abi.encodeWithSelector(
                    AeraVaultAssetRegistry
                        .Aera__CannotRemoveNumeraireAsset
                        .selector,
                    feeToken
                )
            );
        } else {
            vm.expectRevert(
                abi.encodeWithSelector(
                    AeraVaultAssetRegistry.Aera__CannotRemoveFeeToken.selector,
                    feeToken
                )
            );
        }
        assetRegistry.removeAsset(address(feeToken));
    }

    function test_removeAsset_fail_whenAssetBalanceIsNotZero() public {
        deal(address(assets[nonNumeraireId].asset), address(vault), 1);

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__AssetBalanceIsNotZero.selector,
                assets[nonNumeraireId].asset
            )
        );
        assetRegistry.removeAsset(address(assets[nonNumeraireId].asset));
    }

    function test_removeAsset_fail_whenAssetIsNotRegistered() public {
        // this high number (49) is just to make sure we didn't already
        // create this asset previously, and so ensures the address is different
        (address assetAddress,) = _createAsset(false, address(0), 49);
        ERC20Mock erc20 = ERC20Mock(assetAddress);

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__AssetNotRegistered.selector, erc20
            )
        );
        assetRegistry.removeAsset(assetAddress);
    }

    function test_removeERC20Asset_success() public {
        _removeAsset_success(nonNumeraireId, false);
    }

    function test_removeERC4626Asset_success() public {
        _removeAsset_success(nonNumeraireERC4626Id, true);
    }

    function _removeAsset_success(uint256 assetId, bool isERC4626) internal {
        uint256 numRegistryAssets = assetRegistry.assets().length;
        IERC20 removalAsset = assets[assetId].asset;

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
            numeraireId--;
        }

        propNumeraire();
        propFeeToken();
        if (isERC4626) {
            propNumNonYieldAssets();
        } else {
            propNumYieldAssets();
        }
        propAssetsSorted();
    }
}
