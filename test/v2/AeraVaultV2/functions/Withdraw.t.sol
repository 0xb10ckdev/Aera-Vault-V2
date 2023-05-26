// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";
import {ERC20Mock} from "test/utils/ERC20Mock.sol";

contract WithdrawTest is TestBaseAeraVaultV2 {
    ICustody.AssetValue[] withdrawAmounts;

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

    function test_withdraw_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        vault.withdraw(withdrawAmounts, false);
    }

    function test_withdraw_fail_whenFinalized() public {
        vault.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        vault.withdraw(withdrawAmounts, false);
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

        vault.withdraw(withdrawAmounts, false);
    }

    function test_withdraw_fail_whenAssetIsDuplicated() public {
        withdrawAmounts[0].asset = withdrawAmounts[1].asset;

        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__AssetIsDuplicated.selector,
                withdrawAmounts[0].asset
            )
        );

        vault.withdraw(withdrawAmounts, false);
    }

    function test_withdraw_fail_withdrawalAmountExceedsHolding() public {
        ICustody.AssetValue[] memory holdings = vault.holdings();

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

        vault.withdraw(withdrawAmounts, false);
    }

    function test_withdraw_fail_withdrawalAmountExceedsAvailable() public {
        vm.prank(_GUARDIAN);
        _startRebalance(_generateValidRequest());

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

        vault.withdraw(withdrawAmounts, false);
    }

    function test_withdraw_success() public virtual {
        uint256[] memory balances = new uint256[](withdrawAmounts.length);
        for (uint256 i = 0; i < withdrawAmounts.length; i++) {
            balances[i] = withdrawAmounts[i].asset.balanceOf(address(this));
        }

        vm.expectEmit(true, true, true, true, address(vault));
        emit Withdraw(withdrawAmounts, false);

        vault.withdraw(withdrawAmounts, false);

        for (uint256 i = 0; i < withdrawAmounts.length; i++) {
            assertEq(
                withdrawAmounts[i].asset.balanceOf(address(this)) - balances[i],
                withdrawAmounts[i].value
            );
        }
    }

    function test_withdraw_success_withClaim() public virtual {
        vm.prank(_GUARDIAN);
        _startRebalance(_generateValidRequest());

        uint256[] memory balances = new uint256[](withdrawAmounts.length);
        for (uint256 i = 0; i < withdrawAmounts.length; i++) {
            balances[i] = withdrawAmounts[i].asset.balanceOf(address(this));
            withdrawAmounts[i].value =
                withdrawAmounts[0].asset.balanceOf(address(vault)) +
                1;
        }

        vm.expectEmit(true, true, true, true, address(vault));
        emit Withdraw(withdrawAmounts, true);

        vault.withdraw(withdrawAmounts, true);

        for (uint256 i = 0; i < withdrawAmounts.length; i++) {
            assertEq(
                withdrawAmounts[i].asset.balanceOf(address(this)) - balances[i],
                withdrawAmounts[i].value
            );
        }
    }
}
