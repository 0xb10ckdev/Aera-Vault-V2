// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {TestBase} from "../../../utils/TestBase.sol";
import "../../../../src/v2/dependencies/openzeppelin/IERC20.sol";
import "../../../../src/v2/interfaces/ICustody.sol";
import "../../../../src/v2/interfaces/ICustodyEvents.sol";

abstract contract TestBaseCustody is TestBase, ICustodyEvents {
    ICustody custody;
    IERC20[] erc20Assets;

    function _generateRequest()
        internal
        virtual
        returns (ICustody.AssetValue[] memory requests)
    {
        requests = new ICustody.AssetValue[](2);

        for (uint256 i = 0; i < 2; i++) {
            requests[i] = ICustody.AssetValue({
                asset: erc20Assets[i],
                value: 0.5e18
            });
        }
    }

    function _startRebalance() internal {
        custody.startRebalance(
            _generateRequest(),
            block.timestamp + 10,
            block.timestamp + 10000
        );
    }
}
