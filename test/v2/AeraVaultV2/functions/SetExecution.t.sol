// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";
import "src/v2/AeraBalancerExecution.sol";
import {IOracleMock} from "test/utils/OracleMock.sol";

contract SetExecutionTest is TestBaseAeraVaultV2 {
    AeraBalancerExecution newExecution;

    function setUp() public override {
        super.setUp();

        newExecution = new AeraBalancerExecution(_generateVaultParams());
    }

    function test_setExecution_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        vault.setExecution(address(newExecution));
    }

    function test_setExecution_fail_whenFinalized() public {
        vault.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        vault.setExecution(address(newExecution));
    }

    function test_setExecution_fail_whenExecutionIsZeroAddress() public {
        vm.expectRevert(ICustody.Aera__ExecutionIsZeroAddress.selector);

        vault.setExecution(address(0));
    }

    function test_setExecution_fail_whenExecutionIsNotValid() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__ExecutionIsNotValid.selector, address(1)
            )
        );

        vault.setExecution(address(1));
    }

    function test_setExecution_success_whenOraclePriceIsInvalid()
        public
        virtual
    {
        IOracleMock(address(assetsInformation[nonNumeraire].oracle))
            .setLatestAnswer(-1);

        vm.expectEmit(true, true, true, true, address(vault));
        emit SetExecution(address(newExecution));

        vault.setExecution(address(newExecution));
    }

    function test_setExecution_success() public virtual {
        vm.expectEmit(true, true, true, true, address(vault));
        emit SetExecution(address(newExecution));

        vault.setExecution(address(newExecution));

        assertEq(address(vault.execution()), address(newExecution));
    }
}
