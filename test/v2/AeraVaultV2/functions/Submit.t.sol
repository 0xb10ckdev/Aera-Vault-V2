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

    function test_submit_fail_whenSubmitRedeemERC4626AssetFromOwner() public {
        Operation[] memory hookOperations = new Operation[](1);
        hooks.addTargetSighash(
            address(yieldAssets[0]), IERC4626.withdraw.selector
        );
        hookOperations[0] = Operation({
            target: address(yieldAssets[0]),
            value: 0,
            data: abi.encodeWithSelector(
                IERC4626.withdraw.selector, 1, address(this), address(this)
                )
        });

        vm.prank(_GUARDIAN);

        vm.expectRevert(
            IVault.Aera__SubmitRedeemERC4626AssetFromOwner.selector
        );
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

    function test_submit_fail_whenUseReservedFees() public {
        uint256 feeTokenId;
        uint256 nonFeeTokenId;
        IERC20 nonFeeToken;

        for (uint256 i = 0; i < assetsInformation.length; i++) {
            if (assetsInformation[i].asset == feeToken) {
                feeTokenId = i;
            } else if (!assetsInformation[i].isERC4626) {
                nonFeeTokenId = i;
                nonFeeToken = assetsInformation[i].asset;
            }
        }

        uint256 feeTokenAmount = feeToken.balanceOf(address(vault));
        uint256 nonFeeTokenAmount = feeTokenAmount
            * oraclePrices[nonFeeTokenId] * _getScaler(nonFeeToken)
            / oraclePrices[feeTokenId] / _getScaler(feeToken);

        Operation[] memory ops = new Operation[](2);

        hooks.addTargetSighash(address(feeToken), IERC20.transfer.selector);
        ops[0] = Operation({
            target: address(feeToken),
            value: 0,
            data: abi.encodeWithSignature(
                "transfer(address,uint256)", address(this), feeTokenAmount
                )
        });

        hooks.addTargetSighash(
            address(nonFeeToken), IERC20.transferFrom.selector
        );
        ops[1] = Operation({
            target: address(nonFeeToken),
            value: 0,
            data: abi.encodeWithSignature(
                "transferFrom(address,address,uint256)",
                _GUARDIAN,
                address(vault),
                nonFeeTokenAmount
                )
        });

        skip(1000);

        deal(address(nonFeeToken), _GUARDIAN, nonFeeTokenAmount);

        vm.startPrank(_GUARDIAN);
        nonFeeToken.approve(address(vault), nonFeeTokenAmount);

        vm.expectRevert(IVault.Aera__CannotUseReservedFees.selector);
        vault.submit(ops);
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
