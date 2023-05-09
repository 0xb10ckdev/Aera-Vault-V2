// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC20Mock} from "../../../../utils/ERC20Mock.sol";
import "../TestBaseCustody.sol";

abstract contract BaseWithdrawTest is TestBaseCustody {
    ICustody.AssetValue[] withdrawAmounts;

    function test_withdraw_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        custody.withdraw(withdrawAmounts, false);
    }

    function test_withdraw_fail_whenFinalized() public {
        custody.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        custody.withdraw(withdrawAmounts, false);
    }

    function test_withdraw_fail_whenAssetIsNotRegistered() public {
        IERC20 erc20 = IERC20(
            address(new ERC20Mock("Token", "TOKEN", 18, 1e30))
        );
        withdrawAmounts[0].asset = erc20;

        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__AssetIsNotRegistered.selector,
                erc20
            )
        );

        custody.withdraw(withdrawAmounts, false);
    }

    function test_withdraw_fail_withdrawalAmountExceedsHolding() public {
        ICustody.AssetValue[] memory holdings = custody.holdings();

        for (uint256 i = 0; i < holdings.length; i++) {
            if (withdrawAmounts[0].asset == holdings[i].asset) {
                withdrawAmounts[0].value = holdings[i].value + 1;
                break;
            }
        }

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

    function test_withdraw_success() public virtual {
        uint256[] memory balances = new uint256[](withdrawAmounts.length);
        for (uint256 i = 0; i < withdrawAmounts.length; i++) {
            balances[i] = withdrawAmounts[i].asset.balanceOf(address(this));
        }

        vm.expectEmit(true, true, true, true, address(custody));
        emit Withdraw(withdrawAmounts, false);

        custody.withdraw(withdrawAmounts, false);

        for (uint256 i = 0; i < withdrawAmounts.length; i++) {
            assertEq(
                withdrawAmounts[i].asset.balanceOf(address(this)) - balances[i],
                withdrawAmounts[i].value
            );
        }
    }
}
