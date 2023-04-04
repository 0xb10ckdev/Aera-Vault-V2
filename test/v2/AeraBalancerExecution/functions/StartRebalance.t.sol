// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../../utils/TestBaseExecution/functions/StartRebalance.sol";
import "../TestBaseBalancerExecution.sol";

contract StartRebalanceTest is
    BaseStartRebalanceTest,
    TestBaseBalancerExecution
{
    function test_startRebalance_fail_whenRebalancingIsOnGoing() public {
        _startRebalance(_generateRequestWith2Assets());

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraBalancerExecution.Aera__RebalancingIsOnGoing.selector,
                balancerExecution.rebalanceEndTime()
            )
        );

        balancerExecution.startRebalance(
            _generateRequestWith2Assets(),
            block.timestamp,
            block.timestamp + 10000
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
