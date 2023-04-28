// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC20Mock} from "../../../../utils/ERC20Mock.sol";
import "../TestBaseCustody.sol";

abstract contract BaseWithdrawTest is TestBaseCustody {
    ICustody.AssetValue[] withdrawalAmounts;

    function test_withdraw_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        custody.withdraw(withdrawalAmounts, false);
    }

    function test_withdraw_fail_whenAssetIsNotRegistered() public {
        IERC20 erc20 = IERC20(
            address(new ERC20Mock("Token", "TOKEN", 18, 1e30))
        );
        withdrawalAmounts[0].asset = erc20;

        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__AssetIsNotRegistered.selector,
                erc20
            )
        );

        custody.withdraw(withdrawalAmounts, false);
    }

    function test_withdraw_fail_withdrawalAmountExceedsHolding() public {
        ICustody.AssetValue[] memory holdings = custody.holdings();

        for (uint256 i = 0; i < holdings.length; i++) {
            if (withdrawalAmounts[0].asset == holdings[i].asset) {
                withdrawalAmounts[0].value = holdings[i].value + 1;
                break;
            }
        }

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

    function test_withdraw_success() public virtual {
        uint256[] memory balances = new uint256[](withdrawalAmounts.length);
        for (uint256 i = 0; i < withdrawalAmounts.length; i++) {
            balances[i] = withdrawalAmounts[i].asset.balanceOf(address(this));
        }

        vm.expectEmit(true, true, true, true, address(custody));
        emit Withdraw(withdrawalAmounts, false);

        custody.withdraw(withdrawalAmounts, false);

        for (uint256 i = 0; i < withdrawalAmounts.length; i++) {
            assertEq(
                withdrawalAmounts[i].asset.balanceOf(address(this)) -
                    balances[i],
                withdrawalAmounts[i].value
            );
        }
    }
}
