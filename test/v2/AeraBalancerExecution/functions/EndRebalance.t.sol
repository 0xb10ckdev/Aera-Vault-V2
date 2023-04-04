// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import "../../utils/TestBaseExecution/functions/EndRebalance.sol";
import "../TestBaseBalancerExecution.sol";

contract EndRebalanceTest is BaseEndRebalanceTest, TestBaseBalancerExecution {
    event EndRebalance();

    function test_endRebalance_fail_whenRebalancingIsOnGoing() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AeraBalancerExecution.Aera__RebalancingIsOnGoing.selector,
                0
            )
        );
        balancerExecution.endRebalance();

        _startRebalance(_generateRequestWith3Assets());

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraBalancerExecution.Aera__RebalancingIsOnGoing.selector,
                balancerExecution.rebalanceEndTime()
            )
        );
        balancerExecution.endRebalance();
    }

    function test_endRebalance_success() public {
        _startRebalance(_generateRequestWith3Assets());

        vm.warp(balancerExecution.rebalanceEndTime());

        _swap(_getTargetAmounts());

        IExecution.AssetValue[] memory holdings = balancerExecution.holdings();
        uint256[] memory balances = new uint256[](holdings.length);

        for (uint256 i = 0; i < holdings.length; i++) {
            balances[i] = holdings[i].asset.balanceOf(address(this));
        }

        vm.expectEmit(true, true, true, true, address(balancerExecution));
        emit EndRebalance();

        balancerExecution.endRebalance();

        for (uint256 i = 0; i < holdings.length; i++) {
            assertEq(
                holdings[i].asset.balanceOf(address(this)),
                balances[i] + holdings[i].value
            );
        }
    }
}
