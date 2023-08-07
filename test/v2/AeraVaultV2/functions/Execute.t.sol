// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

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

    function test_execute_fail_whenOperationFails() public {
        operation.target = address(this);

        vm.expectRevert(
            abi.encodeWithSelector(ICustody.Aera__ExecutionFailed.selector, "")
        );

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

    function test_execute_increases_fees() public {
        address feeRecipient = address(1);
        vault.setGuardianAndFeeRecipient(_USER, feeRecipient);

        assertEq(vault.feeTotal(), 0);
        assertEq(vault.fees(feeRecipient), 0);

        vm.warp(block.timestamp + 1000);

        test_execute_success();

        assertEq(vault.feeTotal(), 499999);
        assertEq(vault.fees(feeRecipient), 499999);
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
