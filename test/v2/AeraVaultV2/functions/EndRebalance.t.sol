// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../../utils/TestBaseCustody/functions/EndRebalance.sol";
import "../TestBaseAeraVaultV2.sol";

contract EndRebalanceTest is BaseEndRebalanceTest, TestBaseAeraVaultV2 {
    function _generateRequest()
        internal
        override
        returns (ICustody.AssetValue[] memory requests)
    {
        return _generateValidRequest();
    }
}
