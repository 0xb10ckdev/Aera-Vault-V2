// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../../../../../src/v2/AeraVaultAssetRegistry.sol";
import "../TestBaseCustody.sol";

abstract contract BaseSetAssetRegistryTest is TestBaseCustody {
    AeraVaultAssetRegistry newAssetRegistry;

    function test_setAssetRegistry_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        custody.setAssetRegistry(address(newAssetRegistry));
    }

    function test_setAssetRegistry_fail_whenFinalized() public {
        custody.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        custody.setAssetRegistry(address(newAssetRegistry));
    }

    function test_setAssetRegistry_fail_whenAssetRegistryIsZeroAddress()
        public
    {
        vm.expectRevert(ICustody.Aera__AssetRegistryIsZeroAddress.selector);

        custody.setAssetRegistry(address(0));
    }

    function test_setAssetRegistry_success() public virtual {
        vm.expectEmit(true, true, true, true, address(custody));
        emit SetAssetRegistry(address(newAssetRegistry));

        custody.setAssetRegistry(address(newAssetRegistry));

        assertEq(address(custody.assetRegistry()), address(newAssetRegistry));
    }
}
