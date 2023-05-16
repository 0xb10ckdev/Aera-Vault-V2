// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../../utils/TestBaseCustody/functions/Withdraw.sol";
import "../TestBaseAeraVaultV2.sol";

contract WithdrawTest is BaseWithdrawTest, TestBaseAeraVaultV2 {
    function setUp() public override {
        super.setUp();

        for (uint256 i = 0; i < erc20Assets.length; i++) {
            withdrawAmounts.push(
                ICustody.AssetValue(
                    erc20Assets[i],
                    5 * _getScaler(erc20Assets[i])
                )
            );
        }
    }

    function test_withdraw_fail_withdrawalAmountExceedsAvailable() public {
        vm.prank(_GUARDIAN);
        _startRebalance(_generateRequest());

        withdrawAmounts[0].value =
            withdrawAmounts[0].asset.balanceOf(address(vault)) +
            1;

        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__AmountExceedsAvailable.selector,
                withdrawAmounts[0].asset,
                withdrawAmounts[0].value,
                withdrawAmounts[0].value - 1
            )
        );

        custody.withdraw(withdrawAmounts, false);
    }

    function test_withdraw_success_withClaim() public virtual {
        vm.prank(_GUARDIAN);
        _startRebalance(_generateRequest());

        uint256[] memory balances = new uint256[](withdrawAmounts.length);
        for (uint256 i = 0; i < withdrawAmounts.length; i++) {
            balances[i] = withdrawAmounts[i].asset.balanceOf(address(this));
            withdrawAmounts[i].value =
                withdrawAmounts[0].asset.balanceOf(address(vault)) +
                1;
        }

        vm.expectEmit(true, true, true, true, address(custody));
        emit Withdraw(withdrawAmounts, true);

        custody.withdraw(withdrawAmounts, true);

        for (uint256 i = 0; i < withdrawAmounts.length; i++) {
            assertEq(
                withdrawAmounts[i].asset.balanceOf(address(this)) - balances[i],
                withdrawAmounts[i].value
            );
        }
    }
}
