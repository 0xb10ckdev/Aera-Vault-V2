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
        emit Execute(operation);

        vault.execute(operation);

        assertEq(erc20Assets[0].balanceOf(address(vault)), 0);
        assertEq(erc20Assets[0].balanceOf(address(this)), balance + holding);
    }
}
