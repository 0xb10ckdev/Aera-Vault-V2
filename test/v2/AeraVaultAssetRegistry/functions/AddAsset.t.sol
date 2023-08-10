// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAssetRegistry.sol";

contract AddAssetTest is TestBaseAssetRegistry {
    event AssetAdded(IAssetRegistry.AssetInformation asset);

    IAssetRegistry.AssetInformation newERC20Asset;
    IAssetRegistry.AssetInformation newERC4626Asset;

    function setUp() public virtual override {
        _deploy();

        // this high number (50) is just to make sure we didn't already
        // create this asset previously, and so ensures the address is different
        (, newERC20Asset) = _createAsset(false, address(0), 50);
        (, newERC4626Asset) =
            _createAsset(true, address(newERC20Asset.asset), 50);
    }

    function test_addAsset_fail_whenCallerIsNotOwner() public {
        hoax(_USER);

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        assetRegistry.addAsset(newERC20Asset);
    }

    function test_addAsset_fail_whenERC20OracleIsZeroAddress() public {
        newERC20Asset.oracle = AggregatorV2V3Interface(address(0));

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__ERC20OracleIsZeroAddress.selector,
                newERC20Asset.asset
            )
        );
        assetRegistry.addAsset(newERC20Asset);
    }

    function test_addAsset_fail_whenERC4626OracleIsNotZeroAddress() public {
        newERC4626Asset.oracle = AggregatorV2V3Interface(address(1));

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry
                    .Aera__ERC4626OracleIsNotZeroAddress
                    .selector,
                newERC4626Asset.asset
            )
        );
        assetRegistry.addAsset(newERC4626Asset);
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

    function test_addERC20Asset_success() public {
        _addAsset_success(false);
    }

    function test_addERC4626Asset_success() public {
        _addAsset_success(true);
    }

    function _addAsset_success(bool isERC4626) internal {
        uint256 numRegistryAssets = assetRegistry.assets().length;

        vm.expectEmit(true, true, true, true, address(assetRegistry));
        IAssetRegistry.AssetInformation memory newAsset;
        if (isERC4626) {
            newAsset = newERC4626Asset;
        } else {
            newAsset = newERC20Asset;
        }
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
        if (isERC4626) {
            propNumNonYieldAssets();
        } else {
            propNumYieldAssets();
        }
        propAssetsSorted();
    }
}
