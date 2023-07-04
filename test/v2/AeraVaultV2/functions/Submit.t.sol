// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

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
        vm.expectRevert(ICustody.Aera__CallerIsNotGuardian.selector);

        vm.prank(_USER);
        vault.submit(operations);
    }

    function test_submit_fail_whenOperationIsNotAllowed() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IHooks.Aera__CallIsNotAllowed.selector, operations[0]
            )
        );

        vm.prank(_GUARDIAN);
        vault.submit(operations);
    }

    function test_submit_fail_whenOperationsFail() public {
        for (uint256 i = 0; i < operations.length; i++) {
            hooks.addTargetSighash(
                operations[i].target,
                bytes4(keccak256("transfer(address,uint256)"))
            );
        }

        operations[0].data = abi.encodeWithSignature(
            "transfer(address,uint256)", address(this), type(uint256).max
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__SubmissionFailed.selector, 0, ""
            )
        );

        vm.prank(_GUARDIAN);
        vault.submit(operations);
    }

    function test_submit_success() public {
        uint256 numERC20Assets = erc20Assets.length;

        for (uint256 i = 0; i < operations.length; i++) {
            hooks.addTargetSighash(
                operations[i].target,
                bytes4(keccak256("transfer(address,uint256)"))
            );
        }

        uint256[] memory holdings = new uint256[](numERC20Assets);
        uint256[] memory balances = new uint256[](numERC20Assets);

        for (uint256 i = 0; i < numERC20Assets; i++) {
            holdings[i] = erc20Assets[i].balanceOf(address(vault));
            balances[i] = erc20Assets[i].balanceOf(address(this));
        }

        vm.expectEmit(true, true, true, true, address(vault));
        emit Submit(operations);

        vm.prank(_GUARDIAN);
        vault.submit(operations);

        for (uint256 i = 0; i < numERC20Assets; i++) {
            assertEq(erc20Assets[i].balanceOf(address(vault)), holdings[i] - 1);
            assertEq(erc20Assets[i].balanceOf(address(this)), balances[i] + 1);
        }
    }
}
