// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseBalancerExecution.sol";
import "test/v2/utils/TestBase/TestBaseSweepable.sol";

contract SweepTest is TestBaseSweepable, TestBaseBalancerExecution {
    function setUp() public override {
        super.setUp();
        sweepable = ISweepable(address(execution));
    }

    function test_sweep_fail_whenCannotSweepPoolAsset() public {
        vm.expectRevert(
            AeraBalancerExecution.Aera__CannotSweepPoolAsset.selector
        );
        balancerExecution.sweep(assetsInformation[0].asset, _ONE);
    }
}
