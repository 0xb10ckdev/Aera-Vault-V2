// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAeraVaultHooks.sol";

contract BeforeSubmitTest is TestBaseAeraVaultHooks {
    function test_beforeSubmit_fail_whenCallerIsNotVault() public {
        vm.expectRevert(AeraVaultHooks.Aera__CallerIsNotVault.selector);

        vm.prank(_USER);
        hooks.beforeSubmit(new Operation[](0));
    }

    function test_beforeSubmit_fail_whenCallIsNotAllowed() public {
        Operation[] memory operations = new Operation[](1);
        operations[0] = Operation({
            target: address(erc20Assets[0]),
            value: 0,
            data: abi.encodeWithSignature(
                "transfer(address,uint256)", address(this), 1
                )
        });

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultHooks.Aera__CallIsNotAllowed.selector, operations[0]
            )
        );

        vm.prank(address(vault));
        hooks.beforeSubmit(operations);
    }

    function test_beforeSubmit_success() public {
        Operation[] memory operations = new Operation[](2);
        operations[0] = Operation({
            target: address(erc20Assets[0]),
            value: 0,
            data: abi.encodeWithSignature(
                "approve(address,uint256)", address(this), 1
                )
        });
        operations[1] = Operation({
            target: address(erc20Assets[0]),
            value: 0,
            data: abi.encodeWithSignature(
                "transfer(address,uint256)", address(this), 1
                )
        });

        hooks.addTargetSighash(
            address(erc20Assets[0]), IERC20.approve.selector
        );
        hooks.addTargetSighash(
            address(erc20Assets[0]), IERC20.transfer.selector
        );

        vm.prank(address(vault));
        hooks.beforeSubmit(operations);
    }
}
