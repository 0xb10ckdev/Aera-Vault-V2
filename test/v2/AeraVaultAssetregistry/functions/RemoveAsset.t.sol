// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../TestBaseAssetRegistry.sol";

contract RemoveAssetTest is TestBaseAssetRegistry {
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
        (ERC20Mock erc20, ) = createAsset();

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__NoAssetIsRegistered.selector,
                erc20
            )
        );
        assetRegistry.removeAsset(address(erc20));
    }

    function test_removeAsset_success() public {
        assetRegistry.removeAsset(address(assets[nonNumeraire].asset));

        for (uint256 i = nonNumeraire; i < numAssets - 1; i++) {
            assets[i] = assets[i + 1];
        }

        delete assets[numAssets - 1];

        checkRegisteredAssets();
    }
}
