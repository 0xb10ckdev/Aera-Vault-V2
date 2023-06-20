// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseConstraints.sol";

contract SetAssetRegistryTest is TestBaseConstraints {
    AeraVaultAssetRegistry newAssetRegistry;

    function setUp() public override {
        super.setUp();

        newAssetRegistry = new AeraVaultAssetRegistry(
            assetsInformation,
            numeraire,
            feeToken
        );
    }

    function test_setAssetRegistry_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        constraints.setAssetRegistry(address(newAssetRegistry));
    }

    function test_setAssetRegistry_fail_whenAssetRegistryIsZeroAddress()
        public
    {
        vm.expectRevert(ICustody.Aera__AssetRegistryIsZeroAddress.selector);

        constraints.setAssetRegistry(address(0));
    }

    function test_setAssetRegistry_fail_whenAssetRegistryIsNotValid() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__AssetRegistryIsNotValid.selector, address(1)
            )
        );

        constraints.setAssetRegistry(address(1));
    }

    function test_setAssetRegistry_success() public virtual {
        vm.expectEmit(true, true, true, true, address(constraints));
        emit SetAssetRegistry(address(newAssetRegistry));

        constraints.setAssetRegistry(address(newAssetRegistry));

        assertEq(
            address(constraints.assetRegistry()), address(newAssetRegistry)
        );
    }
}
