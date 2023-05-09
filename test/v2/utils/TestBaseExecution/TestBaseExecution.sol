// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {TestBase} from "../../../utils/TestBase.sol";
import "../../../../src/v2/dependencies/openzeppelin/IERC20.sol";
import "../../../../src/v2/interfaces/IExecution.sol";
import "../../../../src/v2/interfaces/IExecutionEvents.sol";

abstract contract TestBaseExecution is TestBase, IExecutionEvents {
    IExecution execution;
    IERC20[] erc20Assets;

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
            _generateRequest(),
            block.timestamp + 10,
            block.timestamp + 10000
        );
    }
}
