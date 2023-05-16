// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {TestBase} from "../../../utils/TestBase.sol";
import {TestBaseVariables} from "../../utils/TestBase/TestBaseVariables.sol";
import "../../../../src/v2/dependencies/openzeppelin/IERC20.sol";
import "../../../../src/v2/dependencies/openzeppelin/IERC4626.sol";
import "../../../../src/v2/interfaces/ICustody.sol";
import "../../../../src/v2/interfaces/ICustodyEvents.sol";

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
