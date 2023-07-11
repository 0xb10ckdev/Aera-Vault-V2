// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultHooks.sol";

contract BeforeSubmitTest is TestBaseAeraVaultHooks {
    function test_beforeSubmit_fail_whenCallerIsNotCustody() public {
        vm.expectRevert(IHooks.Aera__CallerIsNotCustody.selector);

        vm.prank(_USER);
        hooks.beforeSubmit(new Operation[](0));
    }

    function test_beforeSubmit_fail_whenTargetIsHooks() public {
        Operation[] memory operations = new Operation[](1);
        operations[0] = Operation({
            target: address(hooks),
            value: 0,
            data: abi.encodeWithSignature(
                "transfer(address,uint256)", address(this), 1
                )
        });

        vm.expectRevert(IHooks.Aera__TargetIsHooks.selector);

        vm.prank(address(vault));
        hooks.beforeSubmit(operations);
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
                IHooks.Aera__CallIsNotAllowed.selector, operations[0]
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

        hooks.addTargetSighash(address(erc20Assets[0]), _TRANSFER_SELECTOR);

        vm.prank(address(vault));
        hooks.beforeSubmit(operations);
    }
}
