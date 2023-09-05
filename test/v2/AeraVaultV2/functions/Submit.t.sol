// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAeraVaultV2.sol";

contract SubmitTest is TestBaseAeraVaultV2 {
    Operation[] public operations;

    function setUp() public override {
        super.setUp();

        for (uint256 i = 0; i < erc20Assets.length; i++) {
            operations.push(
                Operation({
                    target: address(erc20Assets[i]),
                    value: 0,
                    data: abi.encodeWithSignature(
                        "transfer(address,uint256)", address(this), 1
                        )
                })
            );
        }
    }

    function test_submit_fail_whenCallerIsNotGuardian() public {
        vm.expectRevert(IVault.Aera__CallerIsNotGuardian.selector);

        vm.prank(_USER);
        vault.submit(operations);
    }

    function test_submit_fail_whenSubmitTransfersAssetFromOwner() public {
        Operation[] memory hookOperations = new Operation[](1);
        hooks.addTargetSighash(_USDC_ADDRESS, IERC20.transferFrom.selector);
        hookOperations[0] = Operation({
            target: _USDC_ADDRESS,
            value: 0,
            data: abi.encodeWithSelector(
                IERC20.transferFrom.selector, address(this), address(vault), _ONE
                )
        });

        vm.prank(_GUARDIAN);

        vm.expectRevert(IVault.Aera__SubmitTransfersAssetFromOwner.selector);
        vault.submit(hookOperations);
    }

    function test_submit_fail_whenSubmitTargetIsHooks() public {
        AssetValue[] memory amounts = new AssetValue[](0);
        Operation[] memory hookOperations = new Operation[](1);
        hooks.addTargetSighash(address(hooks), IHooks.beforeDeposit.selector);
        hookOperations[0] = Operation({
            target: address(vault.hooks()),
            value: 0,
            data: abi.encodeWithSelector(IHooks.beforeDeposit.selector, amounts)
        });
        vm.prank(_GUARDIAN);
        vm.expectRevert(IVault.Aera__SubmitTargetIsHooksAddress.selector);
        vault.submit(hookOperations);
    }

    function test_submit_fail_whenSubmitTargetIsVault() public {
        Operation[] memory vaultOperations = new Operation[](1);
        hooks.addTargetSighash(address(vault), IVault.finalize.selector);
        vaultOperations[0] = Operation({
            target: address(vault),
            value: 0,
            data: abi.encodeWithSelector(IVault.finalize.selector)
        });
        vm.prank(_GUARDIAN);
        vm.expectRevert(IVault.Aera__SubmitTargetIsVaultAddress.selector);
        vault.submit(vaultOperations);
    }

    function test_submit_fail_whenOperationIsNotAllowed() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultHooks.Aera__CallIsNotAllowed.selector, operations[0]
            )
        );

        vm.prank(_GUARDIAN);
        vault.submit(operations);
    }

    function test_submit_fail_whenOperationsFail() public {
        for (uint256 i = 0; i < operations.length; i++) {
            hooks.addTargetSighash(
                operations[i].target, IERC20.transfer.selector
            );
        }

        operations[0].data = abi.encodeWithSignature(
            "transfer(address,uint256)", address(this), type(uint256).max
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                IVault.Aera__SubmissionFailed.selector, 0, ""
            )
        );

        vm.prank(_GUARDIAN);
        vault.submit(operations);
    }

    function test_submit_fail_whenUseLockedFees() public {
        for (uint256 i = 0; i < operations.length; i++) {
            hooks.addTargetSighash(
                operations[i].target, IERC20.transfer.selector
            );

            if (operations[i].target == address(feeToken)) {
                operations[i].data = abi.encodeWithSignature(
                    "transfer(address,uint256)",
                    address(this),
                    feeToken.balanceOf(address(vault))
                );
            }
        }

        vm.warp(block.timestamp + 1000);

        vm.expectRevert(IVault.Aera__CannotUseReservedFees.selector);

        vm.prank(_GUARDIAN);
        vault.submit(operations);
    }

    function test_submit_success() public {
        uint256 numERC20Assets = erc20Assets.length;

        for (uint256 i = 0; i < operations.length; i++) {
            hooks.addTargetSighash(
                operations[i].target, IERC20.transfer.selector
            );
        }

        uint256[] memory holdings = new uint256[](numERC20Assets);
        uint256[] memory balances = new uint256[](numERC20Assets);

        for (uint256 i = 0; i < numERC20Assets; i++) {
            holdings[i] = erc20Assets[i].balanceOf(address(vault));
            balances[i] = erc20Assets[i].balanceOf(address(this));
        }

        vm.expectEmit(true, true, true, true, address(vault));
        emit Submitted(vault.owner(), operations);

        vm.prank(_GUARDIAN);
        vault.submit(operations);

        for (uint256 i = 0; i < numERC20Assets; i++) {
            assertEq(erc20Assets[i].balanceOf(address(vault)), holdings[i] - 1);
            assertEq(erc20Assets[i].balanceOf(address(this)), balances[i] + 1);
        }
    }

    function test_submit_increases_fees() public {
        address feeRecipient = address(1);
        vault.setGuardianAndFeeRecipient(_GUARDIAN, feeRecipient);

        assertEq(vault.feeTotal(), 0);
        assertEq(vault.fees(feeRecipient), 0);

        vm.warp(block.timestamp + 1000);

        test_submit_success();

        assertEq(vault.feeTotal(), 499999);
        assertEq(vault.fees(feeRecipient), 499999);
    }
}
