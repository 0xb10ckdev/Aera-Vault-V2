// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAeraVaultV2.sol";

contract ExecuteTest is TestBaseAeraVaultV2 {
    Operation public operation;

    function setUp() public override {
        super.setUp();

        operation = Operation({
            target: address(erc20Assets[0]),
            value: 0,
            data: abi.encodeWithSignature(
                "transfer(address,uint256)",
                address(this),
                erc20Assets[0].balanceOf(address(vault))
                )
        });
    }

    function test_execute_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        vault.execute(operation);
    }

    function test_execute_fail_whenTargetIsHooks() public {
        AssetValue[] memory amounts = new AssetValue[](0);
        Operation memory hooksOp = Operation({
            target: address(vault.hooks()),
            value: 0,
            data: abi.encodeWithSelector(IHooks.beforeDeposit.selector, amounts)
        });
        vm.expectRevert(ICustody.Aera__ExecuteTargetIsHooksAddress.selector);
        vault.execute(hooksOp);
    }

    function test_execute_fail_whenOperationFails() public {
        operation.target = address(this);

        vm.expectRevert(
            abi.encodeWithSelector(ICustody.Aera__ExecutionFailed.selector, "")
        );
        vault.execute(operation);
    }

    function test_execute_fail_whenFeeTokenBalanceGetLowerThanReservedFees()
        public
    {
        skip(1000);

        vault.setGuardianAndFeeRecipient(_GUARDIAN, address(1));

        assertEq(vault.feeTotal(), 499999);
        assertEq(vault.fees(_FEE_RECIPIENT), 499999);

        deal(address(feeToken), address(vault), 499998);

        AssetValue[] memory holdings = vault.holdings();
        for (uint256 i = 0; i < holdings.length; i++) {
            if (holdings[i].asset == feeToken) {
                assertEq(holdings[i].value, 0);
            } else {
                assertEq(
                    holdings[i].value,
                    holdings[i].asset.balanceOf(address(vault))
                );
            }
        }

        operation = Operation({
            target: address(feeToken),
            value: 0,
            data: abi.encodeWithSignature(
                "transfer(address,uint256)", address(this), 1
                )
        });

        vm.expectRevert(ICustody.Aera__CanNotUseReservedFees.selector);
        vault.execute(operation);
    }

    function test_execute_success() public {
        uint256 holding = erc20Assets[0].balanceOf(address(vault));
        uint256 balance = erc20Assets[0].balanceOf(address(this));

        vm.expectEmit(true, true, true, true, address(vault));
        emit Executed(operation);

        vault.execute(operation);

        assertEq(erc20Assets[0].balanceOf(address(vault)), 0);
        assertEq(erc20Assets[0].balanceOf(address(this)), balance + holding);
    }

    function test_execute_success_withIncreasingFees() public {
        address feeRecipient = address(1);
        vault.setGuardianAndFeeRecipient(_USER, feeRecipient);

        assertEq(vault.feeTotal(), 0);
        assertEq(vault.fees(feeRecipient), 0);

        vm.warp(block.timestamp + 1000);

        test_execute_success();

        assertEq(vault.feeTotal(), 499999);
        assertEq(vault.fees(feeRecipient), 499999);
    }

    function test_execute_success_withIncreasingFeesWhenFeeTokenIsNotEnough()
        public
    {
        skip(1000);

        address feeRecipient = address(1);
        vault.setGuardianAndFeeRecipient(_USER, feeRecipient);

        assertEq(vault.feeTotal(), 499999);
        assertEq(vault.fees(_FEE_RECIPIENT), 499999);
        assertEq(vault.fees(feeRecipient), 0);

        skip(1000);

        deal(address(feeToken), address(vault), 0);

        operation = Operation({
            target: address(erc20Assets[0]),
            value: 0,
            data: abi.encodeWithSignature(
                "approve(address,uint256)", address(this), 0
                )
        });

        vault.execute(operation);

        assertEq(vault.feeTotal(), 899998);
        assertEq(vault.fees(_FEE_RECIPIENT), 499999);
        assertEq(vault.fees(feeRecipient), 399999);
        assertEq(feeToken.balanceOf(address(vault)), 0);
    }

    function test_execute_success_withoutIncreasingFeesWhenPaused() public {
        address feeRecipient = address(1);
        vault.setGuardianAndFeeRecipient(_USER, feeRecipient);

        assertEq(vault.feeTotal(), 0);
        assertEq(vault.fees(feeRecipient), 0);
        vault.pause();

        vm.warp(block.timestamp + 1000);

        test_execute_success();

        assertEq(vault.feeTotal(), 0);
        assertEq(vault.fees(feeRecipient), 0);
    }

    function test_execute_success_withoutIncreasingFeesWhenFinalized()
        public
    {
        address feeRecipient = address(1);
        vault.setGuardianAndFeeRecipient(_USER, feeRecipient);

        assertEq(vault.feeTotal(), 0);
        assertEq(vault.fees(feeRecipient), 0);
        vault.finalize();

        vm.warp(block.timestamp + 1000);
        Operation memory approval = Operation({
            target: address(erc20Assets[0]),
            value: 0,
            data: abi.encodeWithSignature(
                "approve(address,uint256)",
                address(this),
                erc20Assets[0].balanceOf(address(vault))
                )
        });

        vault.execute(approval);

        assertEq(vault.feeTotal(), 0);
        assertEq(vault.fees(feeRecipient), 0);
    }
}
