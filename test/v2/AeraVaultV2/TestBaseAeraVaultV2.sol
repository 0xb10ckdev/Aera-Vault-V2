// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "src/v2/AeraVaultV2.sol";
import "src/v2/interfaces/ICustodyEvents.sol";
import {TestBaseCustody} from "test/v2/utils/TestBase/TestBaseCustody.sol";

contract TestBaseAeraVaultV2 is TestBaseCustody, ICustodyEvents {
    function setUp() public virtual override {
        super.setUp();

        for (uint256 i = 0; i < assets.length; i++) {
            assets[i].approve(
                address(vault), 1_000_000 * _getScaler(assets[i])
            );
        }

        vm.warp(block.timestamp + 1000);

        _deposit();
    }

    function _deposit() internal {
        AssetValue[] memory amounts = new AssetValue[](assets.length);

        for (uint256 i = 0; i < assets.length; i++) {
            amounts[i] = AssetValue({
                asset: assets[i],
                value: (1_000_00e6 / oraclePrices[i]) * _getScaler(assets[i])
            });
        }

        vault.deposit(amounts);
    }
}
