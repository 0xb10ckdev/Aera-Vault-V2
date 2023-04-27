// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../../utils/TestBaseExecution/functions/Sweep.sol";
import "../TestBaseBalancerExecution.sol";

contract SweepTest is BaseSweepTest, TestBaseBalancerExecution {
    function test_sweep_fail_whenCannotSweepPoolAsset() public {
        vm.expectRevert(
            AeraBalancerExecution.Aera__CannotSweepPoolAsset.selector
        );
        balancerExecution.sweep(assets[0].asset, _ONE);
    }
}
