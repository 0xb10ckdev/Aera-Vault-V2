// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../../utils/TestBaseCustody/functions/Finalize.sol";
import "../TestBaseAeraVaultV2.sol";

contract FinalizeTest is BaseFinalizeTest, TestBaseAeraVaultV2 {
    function _generateRequest()
        internal
        view
        override
        returns (ICustody.AssetValue[] memory requests)
    {
        return _generateValidRequest();
    }
}