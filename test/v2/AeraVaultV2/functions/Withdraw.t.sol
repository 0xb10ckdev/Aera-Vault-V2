// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../../utils/TestBaseCustody/functions/Withdraw.sol";
import "../TestBaseAeraVaultV2.sol";

contract WithdrawTest is BaseWithdrawTest, TestBaseAeraVaultV2 {
    function setUp() public override {
        super.setUp();

        for (uint256 i = 0; i < erc20Assets.length; i++) {
            withdrawalAmounts.push(
                ICustody.AssetValue(
                    erc20Assets[i],
                    5 * _getScaler(erc20Assets[i])
                )
            );
        }

        _deposit();
    }

    function test_withdraw_fail_withdrawalAmountExceedsAvailable() public {
        vm.prank(_GUARDIAN);
        _startRebalance(_generateRequestWith3Assets());

        withdrawalAmounts[0].value =
            withdrawalAmounts[0].asset.balanceOf(address(vault)) +
            1;

        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__AmountExceedsAvailable.selector,
                withdrawalAmounts[0].asset,
                withdrawalAmounts[0].value,
                withdrawalAmounts[0].value - 1
            )
        );

        custody.withdraw(withdrawalAmounts, false);
    }

    function test_withdraw_success_withClaim() public virtual {
        vm.prank(_GUARDIAN);
        _startRebalance(_generateRequestWith3Assets());

        uint256[] memory balances = new uint256[](withdrawalAmounts.length);
        for (uint256 i = 0; i < withdrawalAmounts.length; i++) {
            balances[i] = withdrawalAmounts[i].asset.balanceOf(address(this));
            withdrawalAmounts[i].value =
                withdrawalAmounts[0].asset.balanceOf(address(vault)) +
                1;
        }

        vm.expectEmit(true, true, true, true, address(custody));
        emit Withdraw(withdrawalAmounts, true);

        custody.withdraw(withdrawalAmounts, true);

        for (uint256 i = 0; i < withdrawalAmounts.length; i++) {
            assertEq(
                withdrawalAmounts[i].asset.balanceOf(address(this)) -
                    balances[i],
                withdrawalAmounts[i].value
            );
        }
    }
}
