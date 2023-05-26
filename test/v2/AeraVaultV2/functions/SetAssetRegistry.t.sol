// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "src/v2/AeraVaultAssetRegistry.sol";
import "../TestBaseAeraVaultV2.sol";

contract SetAssetRegistryTest is TestBaseAeraVaultV2 {
    AeraVaultAssetRegistry newAssetRegistry;

    function setUp() public override {
        super.setUp();

        newAssetRegistry = new AeraVaultAssetRegistry(
            assetsInformation,
            numeraire
        );
    }

    function test_setAssetRegistry_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        vault.setAssetRegistry(address(newAssetRegistry));
    }

    function test_setAssetRegistry_fail_whenFinalized() public {
        vault.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        vault.setAssetRegistry(address(newAssetRegistry));
    }

    function test_setAssetRegistry_fail_whenAssetRegistryIsZeroAddress()
        public
    {
        vm.expectRevert(ICustody.Aera__AssetRegistryIsZeroAddress.selector);

        vault.setAssetRegistry(address(0));
    }

    function test_setAssetRegistry_fail_whenAssetRegistryIsNotValid() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__AssetRegistryIsNotValid.selector,
                address(1)
            )
        );

        vault.setAssetRegistry(address(1));
    }

    function test_setAssetRegistry_success() public virtual {
        vm.expectEmit(true, true, true, true, address(vault));
        emit SetAssetRegistry(address(newAssetRegistry));

        vault.setAssetRegistry(address(newAssetRegistry));

        assertEq(address(vault.assetRegistry()), address(newAssetRegistry));
    }
}
