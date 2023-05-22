// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "src/v2/AeraBalancerExecution.sol";
import "../TestBaseCustody.sol";

abstract contract BaseSetExecutionTest is TestBaseCustody {
    AeraBalancerExecution newExecution;

    function test_setExecution_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        custody.setExecution(address(newExecution));
    }

    function test_setExecution_fail_whenFinalized() public {
        custody.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        custody.setExecution(address(newExecution));
    }

    function test_setExecution_fail_whenExecutionIsZeroAddress() public {
        vm.expectRevert(ICustody.Aera__ExecutionIsZeroAddress.selector);

        custody.setExecution(address(0));
    }

    function test_setExecution_fail_whenExecutionIsNotValid() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__ExecutionIsNotValid.selector,
                address(1)
            )
        );

        custody.setExecution(address(1));
    }

    function test_setExecution_success() public virtual {
        vm.expectEmit(true, true, true, true, address(custody));
        emit SetExecution(address(newExecution));

        custody.setExecution(address(newExecution));

        assertEq(address(custody.execution()), address(newExecution));
    }
}
