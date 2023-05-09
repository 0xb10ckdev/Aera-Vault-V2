// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../../utils/TestBaseExecution/functions/StartRebalance.sol";
import "../TestBaseBalancerExecution.sol";

contract StartRebalanceTest is
    BaseStartRebalanceTest,
    TestBaseBalancerExecution
{
    function test_startRebalance_success_with_2_assets() public {
        _startRebalance(_generateRequestWith2Assets());
    }

    function test_startRebalance_success_with_3_assets() public {
        _startRebalance(_generateRequestWith3Assets());
    }

    function test_startRebalance_success_with_3_assets_after_2_assets() public {
        _startRebalance(_generateRequestWith2Assets());
        balancerExecution.claimNow();
        _startRebalance(_generateRequestWith3Assets());
    }

    function _generateRequest()
        internal
        view
        override
        returns (IExecution.AssetRebalanceRequest[] memory requests)
    {
        return _generateRequestWith2Assets();
    }
}
