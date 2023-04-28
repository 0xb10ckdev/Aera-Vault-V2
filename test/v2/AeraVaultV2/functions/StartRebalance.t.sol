// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../../utils/TestBaseCustody/functions/StartRebalance.sol";
import "../TestBaseAeraVaultV2.sol";

contract StartRebalanceTest is BaseStartRebalanceTest, TestBaseAeraVaultV2 {
    function _generateRequest()
        internal
        override
        returns (ICustody.AssetValue[] memory requests)
    {
        return _generateRequestWith3Assets();
    }
}
