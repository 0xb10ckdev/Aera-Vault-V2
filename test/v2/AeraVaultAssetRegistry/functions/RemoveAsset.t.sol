// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/IERC4626.sol";
import "../TestBaseAssetRegistry.sol";

contract RemoveAssetTest is TestBaseAssetRegistry {
    event AssetRemoved(address indexed asset);

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
                numeraireAsset
            )
        );
        assetRegistry.removeAsset(numeraireAsset);
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

    function test_removeAsset_fail_whenAssetIsUnderlyingAssetOfERC4626()
        public
    {
        address underlyingAsset = IERC4626(nonNumeraireERC4626Asset).asset();

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry
                    .Aera__AssetIsUnderlyingAssetOfERC4626
                    .selector,
                nonNumeraireERC4626Asset
            )
        );

        assetRegistry.removeAsset(underlyingAsset);
    }

    function test_removeERC20Asset_success() public {
        for (uint256 i = numAssets - 1; i >= 0; i--) {
            if (
                assets[i].isERC4626
                    && address(assets[nonNumeraireId].asset)
                        == IERC4626(address(assets[i].asset)).asset()
            ) {
                _removeAsset_success(i, true);

                for (uint256 j = i; j < numAssets - 1; j++) {
                    assets[j] = assets[j + 1];
                }
                assets.pop();

                numAssets--;

                if (i < nonNumeraireId) {
                    nonNumeraireId--;
                }
            }

            if (i == 0) {
                break;
            }
        }

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
