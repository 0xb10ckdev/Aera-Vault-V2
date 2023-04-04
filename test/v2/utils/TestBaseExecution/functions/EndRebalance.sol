// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseExecution.sol";

abstract contract BaseEndRebalanceTest is TestBaseExecution {
    function test_endRebalance_fail_whenCallerIsNotVault() public virtual {
        vm.startPrank(_USER);

        vm.expectRevert(IExecution.Aera__CallerIsNotVault.selector);
        execution.endRebalance();
    }
}