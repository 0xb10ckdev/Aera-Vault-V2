// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";
import "test/v2/utils/TestBaseCustody/functions/SetAssetRegistry.sol";

contract SetAssetRegistryTest is BaseSetAssetRegistryTest, TestBaseAeraVaultV2 {
    function setUp() public override {
        super.setUp();

        newAssetRegistry = new AeraVaultAssetRegistry(
            assetsInformation,
            numeraire
        );
    }
}
