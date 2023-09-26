// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {TestBase} from "test/utils/TestBase.sol";
import "src/v2/AeraVaultAssetRegistry.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/AeraVaultHooks.sol";
import "src/v2/interfaces/IAssetRegistry.sol";

contract AeraVaultV2Handler is TestBase {
    AeraVaultV2 public vault;
    AeraVaultV2 public vaultWithHooksMock;
    AeraVaultHooks public hooks;
    AeraVaultAssetRegistry public assetRegistry;

    uint256 public beforeValue;
    bool public vaultValueChanged;
    bool public feeTokenBalanceReduced;

    constructor(
        AeraVaultV2 vault_,
        AeraVaultV2 vaultWithHooksMock_,
        AeraVaultHooks hooks_,
        AeraVaultAssetRegistry assetRegistry_
    ) {
        vault = vault_;
        vaultWithHooksMock = vaultWithHooksMock_;
        hooks = hooks_;
        assetRegistry = assetRegistry_;

        beforeValue = vault.value();
    }

    function runDeposit(uint256[50] memory amounts) public {
        IAssetRegistry.AssetInformation[] memory assets =
            vault.assetRegistry().assets();
        AssetValue[] memory depositAmounts = new AssetValue[](assets.length);

        vm.startPrank(vault.owner());
        for (uint256 i = 0; i < assets.length; i++) {
            amounts[i] %= 1000e30;

            deal(address(assets[i].asset), vault.owner(), amounts[i] * 2);
            assets[i].asset.approve(address(vault), amounts[i]);
            assets[i].asset.approve(address(vaultWithHooksMock), amounts[i]);

            depositAmounts[i] =
                AssetValue({asset: assets[i].asset, value: amounts[i]});

            if (amounts[i] > 1e6) {
                vaultValueChanged = true;
            }
        }

        vault.deposit(depositAmounts);
        vaultWithHooksMock.deposit(depositAmounts);
        vm.stopPrank();
    }

    function runWithdraw(uint256[50] memory amounts) public {
        IAssetRegistry.AssetInformation[] memory assets =
            vault.assetRegistry().assets();
        AssetValue[] memory withdrawAmounts = new AssetValue[](assets.length);

        for (uint256 i = 0; i < assets.length; i++) {
            amounts[i] %= assets[i].asset.balanceOf(address(vault));
            withdrawAmounts[i] =
                AssetValue({asset: assets[i].asset, value: amounts[i]});

            if (amounts[i] > 1e6) {
                vaultValueChanged = true;
            }
        }

        vm.startPrank(vault.owner());
        vault.withdraw(withdrawAmounts);
        vaultWithHooksMock.withdraw(withdrawAmounts);
        vm.stopPrank();
    }

    function finalize() public {
        vm.startPrank(vault.owner());
        vault.finalize();
        vaultWithHooksMock.finalize();
        vm.stopPrank();

        vaultValueChanged = true;
    }

    function runExecute(
        uint256 assetIndex,
        uint256 amount,
        uint256 skipTimestamp
    ) public {
        IAssetRegistry.AssetInformation[] memory assets =
            vault.assetRegistry().assets();
        assetIndex %= assets.length;
        amount %= assets[assetIndex].asset.balanceOf(address(vault));

        skip(skipTimestamp % 10000);

        Operation memory operation = Operation({
            target: address(assets[assetIndex].asset),
            value: 0,
            data: abi.encodeWithSelector(
                IERC20.transfer.selector, address(this), amount
                )
        });

        if (amount > 1e6) {
            vaultValueChanged = true;
        }

        vm.startPrank(vault.owner());
        vault.execute(operation);
        vaultWithHooksMock.execute(operation);
        vm.stopPrank();
    }

    function runSubmit(
        uint256[10] memory amounts,
        uint256 skipTimestamp
    ) public {
        IAssetRegistry.AssetInformation[] memory assets =
            vault.assetRegistry().assets();

        skip(skipTimestamp % 10000);

        Operation[] memory operations = new Operation[](assets.length);

        vm.startPrank(hooks.owner());
        for (uint256 i = 0; i < assets.length; i++) {
            amounts[i] %= assets[i].asset.balanceOf(address(vault));
            operations[i] = Operation({
                target: address(assets[i].asset),
                value: 0,
                data: abi.encodeWithSelector(
                    IERC20.transfer.selector, address(uint160(i + 1)), amounts[i]
                    )
            });

            hooks.addTargetSighash(
                operations[i].target, IERC20.transfer.selector
            );

            if (amounts[i] > 1e6) {
                vaultValueChanged = true;
            }
        }
        vm.stopPrank();

        uint256 prevFeeTokenBalance =
            assetRegistry.feeToken().balanceOf(address(vault));

        vm.startPrank(vault.guardian());
        vault.submit(operations);
        vaultWithHooksMock.submit(operations);
        vm.stopPrank();

        uint256 feeTokenBalance =
            assetRegistry.feeToken().balanceOf(address(vault));
        if (
            feeTokenBalance < vault.feeTotal()
                && feeTokenBalance < prevFeeTokenBalance
        ) {
            feeTokenBalanceReduced = true;
        }
    }
}
