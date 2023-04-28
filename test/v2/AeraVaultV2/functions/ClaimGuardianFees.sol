// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../../utils/TestBaseCustody/functions/ClaimGuardianFees.sol";
import "../TestBaseAeraVaultV2.sol";

contract ClaimGuardianFeesTest is
    BaseClaimGuardianFeesTest,
    TestBaseAeraVaultV2
{
    function _generateRequest()
        internal
        override
        returns (ICustody.AssetValue[] memory requests)
    {
        return _generateRequestWith3Assets();
    }
}
