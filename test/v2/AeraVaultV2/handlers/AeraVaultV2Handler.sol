// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {TestBase} from "test/utils/TestBase.sol";
import "src/v2/AeraVaultHooks.sol";
import "src/v2/AeraVaultV2.sol";

import "forge-std/console.sol";

contract AeraVaultV2Handler is TestBase {
    AeraVaultV2 public vault;
    AeraVaultHooks public hooks;

    constructor(AeraVaultV2 vault_, AeraVaultHooks hooks_) {
        vault = vault_;
        hooks = hooks_;
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
                    amounts[i] % assets[i].asset.balanceOf(address(vault)) / 20
                    )
            });
            hooks.addTargetSighash(
                operations[i].target, IERC20.transfer.selector
            );
        }
        vm.stopPrank();

        vm.expectCall(
            address(hooks), abi.encodePacked(hooks.beforeSubmit.selector), 2
        );
        vm.expectCall(
            address(hooks), abi.encodePacked(hooks.afterSubmit.selector), 2
        );

        vm.prank(vault.guardian());
        vault.submit(operations);

        // _updateInvariantVariables();
    }
}
