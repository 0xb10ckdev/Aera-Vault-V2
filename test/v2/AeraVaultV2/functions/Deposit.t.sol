// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";
import {ERC20Mock} from "test/utils/ERC20Mock.sol";

contract DepositTest is TestBaseAeraVaultV2 {
    ICustody.AssetValue[] depositAmounts;

    function setUp() public override {
        super.setUp();

        for (uint256 i = 0; i < erc20Assets.length; i++) {
            depositAmounts.push(
                ICustody.AssetValue(
                    erc20Assets[i],
                    5 * _getScaler(erc20Assets[i])
                )
            );
        }
    }

    function test_deposit_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        vault.deposit(depositAmounts);
    }

    function test_deposit_fail_whenFinalized() public {
        vault.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        vault.deposit(depositAmounts);
    }

    function test_deposit_fail_whenAssetIsNotRegistered() public {
        IERC20 erc20 = IERC20(
            address(new ERC20Mock("Token", "TOKEN", 18, 1e30))
        );
        depositAmounts[0].asset = erc20;

        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__AssetIsNotRegistered.selector,
                erc20
            )
        );

        vault.deposit(depositAmounts);
    }

    function test_deposit_fail_whenAssetIsDuplicated() public {
        depositAmounts[0].asset = depositAmounts[1].asset;

        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__AssetIsDuplicated.selector,
                depositAmounts[0].asset
            )
        );

        vault.deposit(depositAmounts);
    }

    function test_deposit_success() public virtual {
        uint256[] memory balances = new uint256[](depositAmounts.length);
        for (uint256 i = 0; i < depositAmounts.length; i++) {
            balances[i] = depositAmounts[i].asset.balanceOf(address(this));
        }

        vm.expectEmit(true, true, true, true, address(vault));
        emit Deposit(depositAmounts);

        vault.deposit(depositAmounts);

        for (uint256 i = 0; i < depositAmounts.length; i++) {
            assertEq(
                balances[i] - depositAmounts[i].asset.balanceOf(address(this)),
                depositAmounts[i].value
            );
        }
    }
}
