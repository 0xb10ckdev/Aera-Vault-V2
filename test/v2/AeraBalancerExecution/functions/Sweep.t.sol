// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "../../utils/TestBaseExecution/functions/Sweep.sol";
import {ERC20Mock} from "../../../utils/ERC20Mock.sol";
import "../TestBaseBalancerExecution.sol";

contract SweepTest is BaseSweepTest, TestBaseBalancerExecution {
    function setUp() public override {
        super.setUp();

        erc20 = IERC20(address(new ERC20Mock("Token", "TOKEN", 18, 1e30)));
        deal(address(erc20), _USER, 10e18);
    }

    function test_sweep_fail_whenCannotSweepPoolAsset() public {
        vm.expectRevert(
            AeraBalancerExecution.Aera__CannotSweepPoolAsset.selector
        );
        balancerExecution.sweep(assets[0].asset);
    }
}
