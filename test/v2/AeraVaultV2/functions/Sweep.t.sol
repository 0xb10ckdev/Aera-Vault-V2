// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../../utils/TestBase/TestBaseSweepable.sol";
import "../TestBaseAeraVaultV2.sol";

contract SweepTest is TestBaseSweepable, TestBaseAeraVaultV2 {
    function setUp() public override {
        super.setUp();
        sweepable = ISweepable(address(vault));
    }

    function test_sweep_fail_whenCannotSweepRegisteredAsset() public {
        vm.expectRevert(ICustody.Aera__CannotSweepRegisteredAsset.selector);
        vault.sweep(assets[0], _ONE);
    }
}
