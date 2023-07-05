// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "src/v2/AeraVaultHooks.sol";
import "../TestBaseAeraVaultV2.sol";
import {IOracleMock} from "test/utils/OracleMock.sol";

contract SetHooksTest is TestBaseAeraVaultV2 {
    AeraVaultHooks public newHooks;

    function setUp() public override {
        super.setUp();

        newHooks = new AeraVaultHooks(
            address(vault),
            _MAX_DAILY_EXECUTION_LOSS,
            targetSighashAllowlist
        );
    }

    function test_setHooks_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        vault.setHooks(address(newHooks));
    }

    function test_setHooks_fail_whenFinalized() public {
        vault.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        vault.setHooks(address(newHooks));
    }

    function test_setHooks_fail_whenHooksIsZeroAddress() public {
        vm.expectRevert(ICustody.Aera__HooksIsZeroAddress.selector);

        vault.setHooks(address(0));
    }

    function test_setHooks_fail_whenHooksIsNotValid() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__HooksIsNotValid.selector, address(1)
            )
        );

        vault.setHooks(address(1));
    }

    function test_setHooks_success_whenOraclePriceIsInvalid() public {
        IOracleMock(address(assetsInformation[nonNumeraire].oracle))
            .setLatestAnswer(-1);

        vm.expectEmit(true, true, true, true, address(vault));
        emit SetHooks(address(newHooks));

        vault.setHooks(address(newHooks));
    }

    function test_setHooks_success() public {
        vm.expectEmit(true, true, true, true, address(vault));
        emit SetHooks(address(newHooks));

        vault.setHooks(address(newHooks));

        assertEq(address(vault.hooks()), address(newHooks));
    }
}