// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.18;

import {TestBase} from "../../../utils/TestBase.sol";
import "../../../../src/v2/dependencies/openzeppelin/IERC20.sol";
import "../../../../src/v2/interfaces/IExecution.sol";

abstract contract TestBaseExecution is TestBase {
    IExecution execution;
    IERC20[] erc20Assets;

    function _generateRequest()
        internal
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
}
