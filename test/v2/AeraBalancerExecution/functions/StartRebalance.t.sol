// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../TestBaseBalancerExecution.sol";

contract StartRebalanceTest is TestBaseBalancerExecution {
    function test_startRebalance_fail_whenCallerIsNotOwner() public {
        vm.startPrank(_USER);

        vm.expectRevert(AeraBalancerExecution.Aera__CallerIsNotVault.selector);
        balancerExecution.startRebalance(
            _generateRequestWith2Assets(),
            block.timestamp,
            block.timestamp + 10000
        );
    }

    function test_startRebalance_fail_whenRebalancingIsOnGoing() public {
        _startRebalance(_generateRequestWith2Assets());

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraBalancerExecution.Aera__RebalancingIsOnGoing.selector,
                balancerExecution.epochEndTime()
            )
        );

        balancerExecution.startRebalance(
            _generateRequestWith2Assets(),
            block.timestamp,
            block.timestamp + 10000
        );
    }

    function test_startRebalance_fail_whenSumOfWeightIsNotOne() public {
        IExecution.AssetRebalanceRequest[]
            memory requests = _generateRequestWith2Assets();
        requests[0].weight--;

        vm.expectRevert(
            AeraBalancerExecution.Aera__SumOfWeightIsNotOne.selector
        );

        balancerExecution.startRebalance(
            requests,
            block.timestamp,
            block.timestamp + 10000
        );
    }

    function test_startRebalance_fail_whenWeightChangeEndBeforeStart() public {
        vm.expectRevert(
            AeraBalancerExecution.Aera__WeightChangeEndBeforeStart.selector
        );

        balancerExecution.startRebalance(
            _generateRequestWith2Assets(),
            block.timestamp + 100,
            block.timestamp + 10
        );
    }

    function test_startRebalance_fail_whenTokenPositionIsDifferent() public {
        IExecution.AssetRebalanceRequest[]
            memory requests = _generateRequestWith2Assets();
        IERC20 asset = requests[0].asset;
        requests[0].asset = requests[1].asset;
        requests[1].asset = asset;

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraBalancerExecution.Aera__DifferentTokensInPosition.selector,
                requests[0].asset,
                asset,
                0
            )
        );

        balancerExecution.startRebalance(
            requests,
            block.timestamp,
            block.timestamp + 10000
        );
    }

    function test_startRebalance_with_2_assets_success() public {
        _startRebalance(_generateRequestWith2Assets());
    }

    function test_startRebalance_with_3_assets_success() public {
        _startRebalance(_generateRequestWith3Assets());
    }

    function test_startRebalance_with_3_assets_after_2_assets_success() public {
        _startRebalance(_generateRequestWith2Assets());
        balancerExecution.claimNow();
        _startRebalance(_generateRequestWith3Assets());
    }
}
