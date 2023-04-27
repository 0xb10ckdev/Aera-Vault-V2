// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseExecution.sol";

abstract contract BaseStartRebalanceTest is TestBaseExecution {
    function test_startRebalance_fail_whenCallerIsNotVault() public virtual {
        vm.startPrank(_USER);

        vm.expectRevert(IExecution.Aera__CallerIsNotVault.selector);

        _startRebalance();
    }

    function test_startRebalance_fail_whenRebalancingIsOnGoing() public {
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

        _startRebalance();
    }

    function test_startRebalance_fail_whenSumOfWeightsIsNotOne()
        public
        virtual
    {
        IExecution.AssetRebalanceRequest[] memory requests = _generateRequest();
        requests[0].weight--;

        vm.expectRevert(IExecution.Aera__SumOfWeightsIsNotOne.selector);

        execution.startRebalance(
            requests,
            block.timestamp,
            block.timestamp + 10000
        );
    }

    function test_startRebalance_fail_whenWeightChangeEndBeforeStart()
        public
        virtual
    {
        vm.expectRevert(IExecution.Aera__WeightChangeEndBeforeStart.selector);

        execution.startRebalance(
            _generateRequest(),
            block.timestamp + 100,
            block.timestamp + 10
        );
    }
}
