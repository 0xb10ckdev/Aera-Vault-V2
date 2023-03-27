// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../TestBaseExecution.sol";

abstract contract BaseStartRebalanceTest is TestBaseExecution {
    function test_startRebalance_fail_whenCallerIsNotVault() public virtual {
        vm.startPrank(_USER);

        vm.expectRevert(IExecution.Aera__CallerIsNotVault.selector);
        execution.startRebalance(
            _generateRequest(),
            block.timestamp,
            block.timestamp + 10000
        );
    }

    function test_startRebalance_fail_whenSumOfWeightIsNotOne() public virtual {
        IExecution.AssetRebalanceRequest[] memory requests = _generateRequest();
        requests[0].weight--;

        vm.expectRevert(IExecution.Aera__SumOfWeightIsNotOne.selector);

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
