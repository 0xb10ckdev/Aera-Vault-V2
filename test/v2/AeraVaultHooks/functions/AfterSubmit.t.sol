// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAeraVaultHooks.sol";

contract AfterSubmitTest is TestBaseAeraVaultHooks {
    function setUp() public override {
        super.setUp();

        uint256 numAssets = assets.length;

        for (uint256 i = 0; i < numAssets; i++) {
            hooks.addTargetSighash(address(assets[i]), IERC20.approve.selector);
            hooks.addTargetSighash(
                address(assets[i]), IERC20.transfer.selector
            );

            assets[i].approve(
                address(vault), 1_000_000 * _getScaler(assets[i])
            );
        }

        _deposit();
        vault.resume();
    }

    function test_afterSubmit_fail_whenCallerIsNotCustody() public {
        vm.expectRevert(AeraVaultHooks.Aera__CallerIsNotCustody.selector);

        vm.prank(_USER);
        hooks.afterSubmit(new Operation[](0));
    }

    function test_afterSubmit_fail_whenExceedsMaxDailyExecutionLossOnCurrentDay(
    ) public {
        uint256 numAssets = assets.length;

        Operation[] memory operations = new Operation[](numAssets);

        for (uint256 i = 0; i < numAssets; i++) {
            operations[i] = Operation({
                target: address(assets[i]),
                value: 0,
                data: abi.encodeWithSignature(
                    "transfer(address,uint256)",
                    address(this),
                    assets[i].balanceOf(address(vault)) / 2
                    )
            });
        }

        vm.expectRevert(
            AeraVaultHooks.Aera__ExceedsMaxDailyExecutionLoss.selector
        );

        vm.prank(_GUARDIAN);
        vault.submit(operations);
    }

    function test_afterSubmit_fail_whenExceedsMaxDailyExecutionLossOnNextDay()
        public
    {
        uint256 numAssets = assets.length;

        Operation[] memory operations = new Operation[](numAssets);

        for (uint256 i = 0; i < numAssets; i++) {
            operations[i] = Operation({
                target: address(assets[i]),
                value: 0,
                data: abi.encodeWithSignature(
                    "transfer(address,uint256)",
                    address(this),
                    assets[i].balanceOf(address(vault)) / 2
                    )
            });
        }

        vm.warp(block.timestamp + 1 days);

        vm.expectRevert(
            AeraVaultHooks.Aera__ExceedsMaxDailyExecutionLoss.selector
        );

        vm.prank(_GUARDIAN);
        vault.submit(operations);
    }

    function test_afterSubmit_fail_whenAllowanceIsNotZero() public {
        Operation[] memory operations = new Operation[](2);
        operations[0] = Operation({
            target: address(erc20Assets[0]),
            value: 0,
            data: abi.encodeWithSignature(
                "approve(address,uint256)", address(this), 1000
                )
        });
        operations[1] = Operation({
            target: address(erc20Assets[0]),
            value: 0,
            data: abi.encodeWithSignature(
                "transfer(address,uint256)", address(this), 1
                )
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultHooks.Aera__AllowanceIsNotZero.selector,
                erc20Assets[0],
                address(this)
            )
        );

        vm.prank(_GUARDIAN);
        vault.submit(operations);
    }

    function test_afterSubmit_success() public {
        Operation[] memory operations = new Operation[](3);
        operations[0] = Operation({
            target: address(erc20Assets[0]),
            value: 0,
            data: abi.encodeWithSignature(
                "approve(address,uint256)", address(this), 1000
                )
        });
        operations[1] = Operation({
            target: address(erc20Assets[0]),
            value: 0,
            data: abi.encodeWithSignature(
                "transfer(address,uint256)", address(this), 100
                )
        });
        operations[2] = Operation({
            target: address(erc20Assets[0]),
            value: 0,
            data: abi.encodeWithSignature(
                "approve(address,uint256)", address(this), 0
                )
        });

        uint256 balance = erc20Assets[0].balanceOf(address(vault));

        vm.prank(_GUARDIAN);
        vault.submit(operations);

        assertEq(erc20Assets[0].balanceOf(address(vault)), balance - 100);
        assertEq(erc20Assets[0].allowance(address(vault), address(this)), 0);
    }

    function test_afterSubmit_newDay_success() public {
        Operation[] memory operations = new Operation[](3);
        operations[0] = Operation({
            target: address(erc20Assets[0]),
            value: 0,
            data: abi.encodeWithSignature(
                "approve(address,uint256)", address(this), 1000
                )
        });
        operations[1] = Operation({
            target: address(erc20Assets[0]),
            value: 0,
            data: abi.encodeWithSignature(
                "transfer(address,uint256)", address(this), 100
                )
        });
        operations[2] = Operation({
            target: address(erc20Assets[0]),
            value: 0,
            data: abi.encodeWithSignature(
                "approve(address,uint256)", address(this), 0
                )
        });

        uint256 balance = erc20Assets[0].balanceOf(address(vault));

        uint256 hooksCurrentDay = hooks.currentDay();
        uint256 day = block.timestamp / 1 days;
        assertEq(hooksCurrentDay, day);
        vm.warp(block.timestamp + 1 days);
        day = block.timestamp / 1 days;
        assertEq(hooksCurrentDay + 1, day);

        vm.prank(vault.feeRecipient());
        vault.claim();

        uint256 beforeValue = vault.value();
        vm.prank(_GUARDIAN);
        vault.submit(operations);

        assertEq(
            hooks.cumulativeDailyMultiplier(),
            vault.value() * ONE / beforeValue
        );

        assertEq(erc20Assets[0].balanceOf(address(vault)), balance - 100);
        assertEq(erc20Assets[0].allowance(address(vault), address(this)), 0);
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
