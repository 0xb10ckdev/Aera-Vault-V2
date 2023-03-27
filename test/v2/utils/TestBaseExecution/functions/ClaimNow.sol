// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../TestBaseExecution.sol";

abstract contract BaseClaimNowTest is TestBaseExecution {
    function test_claimNow_fail_whenCallerIsNotVault() public virtual {
        vm.startPrank(_USER);

        vm.expectRevert(IExecution.Aera__CallerIsNotVault.selector);
        execution.claimNow();
    }
}
