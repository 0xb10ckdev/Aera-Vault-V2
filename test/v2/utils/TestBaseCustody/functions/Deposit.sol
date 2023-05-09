// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC20Mock} from "../../../../utils/ERC20Mock.sol";
import "../TestBaseCustody.sol";

abstract contract BaseDepositTest is TestBaseCustody {
    ICustody.AssetValue[] depositAmounts;

    function test_deposit_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        custody.deposit(depositAmounts);
    }

    function test_deposit_fail_whenFinalized() public {
        custody.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        custody.deposit(depositAmounts);
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

        custody.deposit(depositAmounts);
    }

    function test_deposit_success() public virtual {
        uint256[] memory balances = new uint256[](depositAmounts.length);
        for (uint256 i = 0; i < depositAmounts.length; i++) {
            balances[i] = depositAmounts[i].asset.balanceOf(address(this));
        }

        vm.expectEmit(true, true, true, true, address(custody));
        emit Deposit(depositAmounts);

        custody.deposit(depositAmounts);

        for (uint256 i = 0; i < depositAmounts.length; i++) {
            assertEq(
                balances[i] - depositAmounts[i].asset.balanceOf(address(this)),
                depositAmounts[i].value
            );
        }
    }
}
