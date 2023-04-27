// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../../utils/TestBaseCustody/functions/Sweep.sol";
import "../TestBaseAeraVaultV2.sol";

contract SweepTest is BaseSweepTest, TestBaseAeraVaultV2 {
    function test_sweep_fail_whenCannotSweepRegisteredAsset() public {
        vm.expectRevert(ICustody.Aera__CannotSweepRegisteredAsset.selector);
        vault.sweep(assets[0].asset, _ONE);
    }
}
