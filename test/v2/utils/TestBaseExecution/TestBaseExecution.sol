// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "src/v2/interfaces/IExecution.sol";
import "src/v2/interfaces/IExecutionEvents.sol";
import {TestBase} from "test/utils/TestBase.sol";
import {TestBaseVariables} from "test/v2/utils/TestBase/TestBaseVariables.sol";

abstract contract TestBaseExecution is
    TestBase,
    TestBaseVariables,
    IExecutionEvents
{
    IExecution execution;

    function _generateRequest()
        internal
        view
        virtual
        returns (IExecution.AssetRebalanceRequest[] memory requests)
    {
        requests = new IExecution.AssetRebalanceRequest[](2);

        for (uint256 i = 0; i < 2; i++) {
            requests[i] = IExecution.AssetRebalanceRequest({
                asset: erc20Assets[i],
                amount: 100e18,
                weight: 0.5e18
            });
        }
    }

    function _startRebalance() internal {
        execution.startRebalance(
            _generateRequest(), block.timestamp + 10, block.timestamp + 10000
        );
    }
}
