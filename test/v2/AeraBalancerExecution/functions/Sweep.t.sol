// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../../utils/TestBase/TestBaseSweepable.sol";
import "../TestBaseBalancerExecution.sol";

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
