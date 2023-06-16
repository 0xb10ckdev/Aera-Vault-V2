// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";
import "src/v2/AeraConstraints.sol";
import {IOracleMock} from "test/utils/OracleMock.sol";

contract SetConstraintsTest is TestBaseAeraVaultV2 {
    AeraConstraints newConstraints;

    function setUp() public override {
        super.setUp();

        newConstraints = new AeraConstraints(address(assetRegistry));
    }

    function test_setConstraints_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        vault.setConstraints(address(newConstraints));
    }

    function test_setConstraints_fail_whenFinalized() public {
        vault.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        vault.setConstraints(address(newConstraints));
    }

    function test_setConstraints_fail_whenConstraintsIsZeroAddress() public {
        vm.expectRevert(ICustody.Aera__ConstraintsIsZeroAddress.selector);

        vault.setConstraints(address(0));
    }

    function test_setConstraints_fail_whenConstraintsIsNotValid() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__ConstraintsIsNotValid.selector, address(1)
            )
        );

        vault.setConstraints(address(1));
    }

    function test_setConstraints_success_whenOraclePriceIsInvalid()
        public
        virtual
    {
        IOracleMock(address(assetsInformation[nonNumeraire].oracle))
            .setLatestAnswer(-1);

        vm.expectEmit(true, true, true, true, address(vault));
        emit SetConstraints(address(newConstraints));

        vault.setConstraints(address(newConstraints));
    }

    function test_setConstraints_success() public virtual {
        vm.expectEmit(true, true, true, true, address(vault));
        emit SetConstraints(address(newConstraints));

        vault.setConstraints(address(newConstraints));

        assertEq(address(vault.constraints()), address(newConstraints));
    }
}
