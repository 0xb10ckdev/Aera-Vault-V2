// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../../utils/TestBaseExecution/functions/StartRebalance.sol";
import "../TestBaseBalancerExecution.sol";

contract StartRebalanceTest is
    BaseStartRebalanceTest,
    TestBaseBalancerExecution
{
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

    function _generateRequest()
        internal
        override
        returns (IExecution.AssetRebalanceRequest[] memory requests)
    {
        return _generateRequestWith2Assets();
    }
}
