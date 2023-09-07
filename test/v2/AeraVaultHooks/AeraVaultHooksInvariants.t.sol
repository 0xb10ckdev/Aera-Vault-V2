// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "./TestBaseAeraVaultHooks.sol";
import "./handlers/AeraVaultHooksHandler.sol";

contract AeraVaultHooksInvariantTest is TestBaseAeraVaultHooks {
    bytes32 internal constant _BEFORE_VALUE_SLOT = bytes32(uint256(7));
    bytes32 internal constant _BEFORE_BALANCE_SLOT = bytes32(uint256(8));

    AeraVaultHooksHandler public handler;

    function setUp() public override {
        super.setUp();

        uint256 numAssets = assets.length;

        AssetValue[] memory amounts = new AssetValue[](numAssets);

        for (uint256 i = 0; i < numAssets; i++) {
            // Calculate amount of assets for 1_000_00e6 value in Numeraire token.
            amounts[i] = AssetValue({
                asset: assets[i],
                value: (1_000_00e6 / oraclePrices[i]) * _getScaler(assets[i])
            });
            assets[i].approve(
                address(vault), 1_000_000 * _getScaler(assets[i])
            );
        }

        vault.deposit(amounts);
        vault.resume();

        handler = new AeraVaultHooksHandler(vault, hooks);

        targetContract(address(handler));
        targetSender(address(this));
    }

    function invariant_beforeValue() public {
        assertEq(
            uint256(vm.load(address(hooks), _BEFORE_VALUE_SLOT)),
            handler.beforeValue()
        );
    }

    function invariant_beforeBalance() public {
        assertEq(
            uint256(vm.load(address(hooks), _BEFORE_BALANCE_SLOT)),
            handler.beforeBalance()
        );
    }

    function invariant_currentDay() public {
        assertEq(hooks.currentDay(), handler.currentDay());
    }

    function invariant_cumulativeDailyMultiplier() public {
        assertEq(
            hooks.cumulativeDailyMultiplier(),
            handler.cumulativeDailyMultiplier()
        );
    }
}
