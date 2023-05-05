// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {TestBase} from "../../../utils/TestBase.sol";
import "../../../../src/v2/dependencies/openzeppelin/IERC20.sol";
import "../../../../src/v2/dependencies/openzeppelin/IERC4626.sol";
import "../../../../src/v2/interfaces/ICustody.sol";
import "../../../../src/v2/interfaces/ICustodyEvents.sol";

abstract contract TestBaseCustody is TestBase, ICustodyEvents {
    ICustody custody;
    IERC20[] assets;
    IERC20[] erc20Assets;
    IERC4626[] yieldAssets;

    function _generateRequest()
        internal
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
