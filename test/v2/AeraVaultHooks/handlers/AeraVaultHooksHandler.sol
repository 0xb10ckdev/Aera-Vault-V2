// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {TestBase} from "test/utils/TestBase.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/AeraVaultHooks.sol";
import "src/v2/interfaces/IAssetRegistry.sol";

contract AeraVaultHooksHandler is TestBase {
    AeraVaultV2 public vault;
    AeraVaultHooks public hooks;

    uint256 public currentDay;
    uint256 public cumulativeDailyMultiplier;
    uint256 public beforeValue;
    uint256 public beforeBalance;

    constructor(AeraVaultV2 _vault, AeraVaultHooks _hooks) {
        vault = _vault;
        hooks = _hooks;

        currentDay = hooks.currentDay();
        cumulativeDailyMultiplier = _ONE;
    }

    function runBeforeSubmit(Operation[5] memory ops) public {
        _addTargetSighashes(_operations(ops));

        vm.prank(address(vault));
        hooks.beforeSubmit(_operations(ops));

        beforeValue = vault.value();
        beforeBalance = address(vault).balance;
    }

    function runAfterSubmit(Operation[5] memory ops) public {
        vm.prank(address(vault));
        hooks.afterSubmit(_operations(ops));

        _updateInvariantVariables();
    }

    function runSubmit(
        uint256[5] memory amounts,
        uint256 skipTimestamp
    ) public {
        IAssetRegistry.AssetInformation[] memory assets =
            vault.assetRegistry().assets();

        uint256 numAssets = assets.length;

        skip(skipTimestamp % 10000);

        Operation[] memory operations = new Operation[](numAssets);

        vm.startPrank(hooks.owner());
        for (uint256 i = 0; i < numAssets; i++) {
            operations[i] = Operation({
                target: address(assets[i].asset),
                value: 0,
                data: abi.encodeWithSelector(
                    IERC20.transfer.selector,
                    address(this),
                    amounts[i] % assets[i].asset.balanceOf(address(vault))
                    )
            });
            hooks.addTargetSighash(
                operations[i].target, IERC20.transfer.selector
            );
        }
        vm.stopPrank();

        vm.prank(vault.feeRecipient());
        vault.claim();

        beforeValue = vault.value();
        beforeBalance = address(vault).balance;

        vm.prank(vault.guardian());
        vault.submit(operations);

        _updateInvariantVariables();
    }

    function _updateInvariantVariables() internal {
        uint256 day = block.timestamp / 1 days;

        if (address(vault).balance < beforeBalance) {
            return;
        }

        if (beforeValue > 0) {
            uint256 newMultiplier = (
                vault.value()
                    * (currentDay == day ? cumulativeDailyMultiplier : _ONE)
            ) / beforeValue;

            if (newMultiplier < _ONE - hooks.maxDailyExecutionLoss()) {
                return;
            }

            cumulativeDailyMultiplier = newMultiplier;
        }

        currentDay = day;
        beforeValue = 0;
        beforeBalance = 0;
    }

    function _operations(Operation[5] memory ops)
        internal
        pure
        returns (Operation[] memory)
    {
        Operation[] memory operations = new Operation[](5);
        for (uint256 i = 0; i < 5; i++) {
            operations[i] = ops[i];
        }

        return operations;
    }

    function _addTargetSighashes(Operation[] memory operations) internal {
        vm.startPrank(hooks.owner());
        for (uint256 i = 0; i < operations.length; i++) {
            hooks.addTargetSighash(
                operations[i].target, _getSelector(operations[i].data)
            );
        }
        vm.stopPrank();
    }

    function _getSelector(bytes memory data) internal pure returns (bytes4) {
        return data[0] | (bytes4(data[1]) >> 8) | (bytes4(data[2]) >> 16)
            | (bytes4(data[3]) >> 24);
    }
}
