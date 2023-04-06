// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseExecution.sol";

abstract contract BaseEndRebalanceTest is TestBaseExecution {
    function test_endRebalance_fail_whenCallerIsNotVault() public virtual {
        vm.startPrank(_USER);

        vm.expectRevert(IExecution.Aera__CallerIsNotVault.selector);
        execution.endRebalance();
    }

    function test_endRebalance_fail_whenRebalancingIsOnGoing() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IExecution.Aera__RebalancingIsOnGoing.selector,
                0
            )
        );
        execution.endRebalance();

        for (uint256 i = 0; i < erc20Assets.length; i++) {
            erc20Assets[i].approve(address(execution), type(uint256).max);
        }

        _startRebalance();

        vm.expectRevert(
            abi.encodeWithSelector(
                IExecution.Aera__RebalancingIsOnGoing.selector,
                execution.rebalanceEndTime()
            )
        );
        execution.endRebalance();
    }
}
