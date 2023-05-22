// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";
import "test/v2/utils/TestBaseCustody/functions/EndRebalance.sol";

contract EndRebalanceTest is BaseEndRebalanceTest, TestBaseAeraVaultV2 {
    function _generateRequest()
        internal
        view
        override
        returns (ICustody.AssetValue[] memory requests)
    {
        return _generateValidRequest();
    }
}
