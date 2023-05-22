// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "src/v2/interfaces/ICustody.sol";
import "src/v2/interfaces/ICustodyEvents.sol";
import {TestBase} from "test/utils/TestBase.sol";
import {TestBaseVariables} from "test/v2/utils/TestBase/TestBaseVariables.sol";

abstract contract TestBaseCustody is
    TestBase,
    TestBaseVariables,
    ICustodyEvents
{
    ICustody custody;

    function _generateRequest()
        internal
        view
        virtual
        returns (ICustody.AssetValue[] memory requests)
    {
        uint256 numAssets = assets.length;
        uint256 averageValue = _ONE / numAssets;

        requests = new ICustody.AssetValue[](numAssets);

        for (uint256 i = 0; i < numAssets; i++) {
            requests[i] = ICustody.AssetValue({
                asset: assets[i],
                value: averageValue
            });
        }

        requests[0].value = requests[0].value + _ONE - averageValue * numAssets;
    }

    function _startRebalance() internal {
        custody.startRebalance(
            _generateRequest(),
            block.timestamp + 10,
            block.timestamp + 10000
        );
    }
}
