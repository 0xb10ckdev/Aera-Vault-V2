// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "src/v2/AeraVaultV2.sol";
import "../TestBaseAssetRegistry.sol";

contract SetCustodyTest is TestBaseAssetRegistry {
    event SetCustody(address custody);

    address internal constant _GUARDIAN = address(0x123456);
    address internal constant _FEE_RECIPIENT = address(0x7890ab);
    uint256 internal constant _MAX_FEE = 10 ** 9;

    AeraVaultV2 public vault;

    function setUp() public override {
        super.setUp();

        vault = new AeraVaultV2(
            address(this),
            address(assetRegistry),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_FEE,
            "Test Vault"
        );
    }

    function test_setCustody_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

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
