// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "./TestBaseAeraVaultV2.sol";
import "./handlers/AeraVaultV2Handler.sol";
import "test/utils/AeraVaultHooksMock.sol";

contract AeraVaultV2InvariantTest is TestBaseAeraVaultV2 {
    AeraVaultV2Handler public handler;
    AeraVaultHooksMock public hooksMock;

    function setUp() public override {
        super.setUp();

        (address deployedVault,,) = factory.create(
            bytes32(_ONE),
            "Test Vault",
            vaultParameters,
            assetRegistryParameters,
            hooksParameters
        );
        AeraVaultV2 vaultWithHooksMock = AeraVaultV2(payable(deployedVault));
        hooksMock = new AeraVaultHooksMock(address(vaultWithHooksMock));
        vaultWithHooksMock.setHooks(address(hooksMock));

        AssetValue[] memory amounts = new AssetValue[](assets.length);
        for (uint256 i = 0; i < assets.length; i++) {
            assets[i].approve(
                address(vaultWithHooksMock),
                1_000_00e6 * _getScaler(assets[i]) / oraclePrices[i]
            );
            amounts[i] = AssetValue({
                asset: assets[i],
                value: 1_000_00e6 * _getScaler(assets[i]) / oraclePrices[i]
            });
        }

        vaultWithHooksMock.deposit(amounts);
        vaultWithHooksMock.resume();

        handler = new AeraVaultV2Handler(
            vault,
            vaultWithHooksMock, 
            hooks, 
            assetRegistry
        );

        targetContract(address(handler));
        targetSender(address(this));
    }

    function invariant_hooksCalledTimes() public {
        assertEq(
            hooksMock.beforeDepositCalled(), hooksMock.afterDepositCalled()
        );
        assertEq(
            hooksMock.beforeWithdrawCalled(), hooksMock.afterWithdrawCalled()
        );
        assertEq(hooksMock.beforeSubmitCalled(), hooksMock.afterSubmitCalled());
        assertEq(
            hooksMock.beforeFinalizeCalled(), hooksMock.afterFinalizeCalled()
        );
    }

    function invariant_vaultValue() public {
        if (handler.vaultValueChanged()) {
            assertNotEq(vault.value(), handler.beforeValue());
        }
    }

    function invariant_feeTokenBalance() public {
        assertFalse(handler.feeTokenBalanceReduced());
    }

    function invariant_allowance() public {
        IAssetRegistry.AssetInformation[] memory assets =
            vault.assetRegistry().assets();

        for (uint256 i = 0; i < assets.length; i++) {
            for (uint256 j = 0; j < assets.length; j++) {
                assertEq(
                    assets[i].asset.allowance(
                        address(vault), address(uint160(j + 1))
                    ),
                    0
                );
            }
        }
    }
}
