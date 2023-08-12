// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAssetRegistry.sol";

contract SetCustodyTest is TestBaseAssetRegistry {
    event SetCustody(address custody);

    function setUp() public override {
        super.setUp();

        assetRegistry = new AeraVaultAssetRegistry(
            address(this),
            assets,
            numeraireId,
            feeToken
        );
    }

    function test_setCustody_fail_whenCallerIsNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(_USER);
        assetRegistry.setCustody(address(vault));
    }

    function test_setCustody_fail_whenCustodyIsAlreadySet() public {
        assetRegistry.setCustody(address(vault));

        vm.expectRevert(
            AeraVaultAssetRegistry.Aera__CustodyIsAlreadySet.selector
        );
        assetRegistry.setCustody(address(0));
    }

    function test_setCustody_fail_whenCustodyIsZeroAddress() public {
        vm.expectRevert(
            AeraVaultAssetRegistry.Aera__CustodyIsZeroAddress.selector
        );

        assetRegistry.setCustody(address(0));
    }

    function test_setCustody_fail_whenCustodyIsNotValid() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__CustodyIsNotValid.selector,
                address(1)
            )
        );

        assetRegistry.setCustody(address(1));
    }

    function test_setCustody_success() public {
        vm.expectEmit(true, true, true, true, address(assetRegistry));
        emit SetCustody(address(vault));

        assetRegistry.setCustody(address(vault));

        assertEq(address(assetRegistry.custody()), address(vault));
    }
}
