// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAeraVaultV2.sol";
import "lib/forge-std/src/StdStorage.sol";
import {ERC20Mock} from "test/utils/ERC20Mock.sol";

contract WithdrawTest is TestBaseAeraVaultV2 {
    using stdStorage for StdStorage;

    AssetValue[] withdrawAmounts;

    function setUp() public override {
        super.setUp();

        AssetValue[] memory holdings = vault.holdings();

        for (uint256 i = 0; i < erc20Assets.length; i++) {
            withdrawAmounts.push(
                AssetValue(erc20Assets[i], holdings[i].value / 2)
            );
        }
    }

    function test_withdraw_fail_whenCallerIsNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(_USER);
        vault.withdraw(withdrawAmounts);
    }

    function test_withdraw_fail_whenHooksIsNotSet() public {
        vm.store(
            address(vault),
            bytes32(stdstore.target(address(vault)).sig("hooks()").find()),
            bytes32(uint256(0))
        );
        vm.expectRevert(IVault.Aera__HooksIsZeroAddress.selector);
        vault.withdraw(withdrawAmounts);
    }

    function test_withdraw_fail_whenFinalized() public {
        vault.finalize();

        vm.expectRevert(IVault.Aera__VaultIsFinalized.selector);

        vault.withdraw(withdrawAmounts);
    }

    function test_withdraw_fail_whenAssetIsNotRegistered() public {
        IERC20 erc20 =
            IERC20(address(new ERC20Mock("Token", "TOKEN", 18, 1e30)));
        withdrawAmounts[0].asset = erc20;

        vm.expectRevert(
            abi.encodeWithSelector(
                IVault.Aera__AssetIsNotRegistered.selector, erc20
            )
        );

        vault.withdraw(withdrawAmounts);
    }

    function test_withdraw_fail_whenAssetIsDuplicated() public {
        withdrawAmounts[0].asset = withdrawAmounts[1].asset;

        vm.expectRevert(
            abi.encodeWithSelector(
                IVault.Aera__AssetIsDuplicated.selector,
                withdrawAmounts[0].asset
            )
        );

        vault.withdraw(withdrawAmounts);
    }

    function test_withdraw_fail_withdrawalAmountExceedsAvailable() public {
        vault.execute(
            Operation({
                target: address(erc20Assets[0]),
                value: 0,
                data: abi.encodeWithSignature(
                    "transfer(address,uint256)", address(this), 1
                    )
            })
        );

        withdrawAmounts[0].value =
            withdrawAmounts[0].asset.balanceOf(address(vault)) + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                IVault.Aera__AmountExceedsAvailable.selector,
                withdrawAmounts[0].asset,
                withdrawAmounts[0].value,
                withdrawAmounts[0].value - 1
            )
        );

        vault.withdraw(withdrawAmounts);
    }

    function test_withdraw_success_whenOraclePriceIsInvalid() public {
        _setInvalidOracle(nonNumeraireId);

        skip(1000);

        vm.expectEmit(true, true, true, true, address(vault));
        emit SpotPricesReverted(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__OraclePriceIsInvalid.selector,
                nonNumeraireId,
                -1
            )
        );

        for (uint256 i = 0; i < withdrawAmounts.length; i++) {
            vm.expectEmit(true, true, true, true, address(vault));
            emit Withdraw(
                vault.owner(),
                withdrawAmounts[i].asset,
                withdrawAmounts[i].value
            );
        }

        vault.withdraw(withdrawAmounts);
    }

    function test_withdraw_success() public {
        uint256[] memory balances = new uint256[](withdrawAmounts.length);
        for (uint256 i = 0; i < withdrawAmounts.length; i++) {
            balances[i] = withdrawAmounts[i].asset.balanceOf(address(this));
        }

        for (uint256 i = 0; i < withdrawAmounts.length; i++) {
            vm.expectEmit(true, true, true, true, address(vault));
            emit Withdraw(
                vault.owner(),
                withdrawAmounts[i].asset,
                withdrawAmounts[i].value
            );
        }

        vault.withdraw(withdrawAmounts);

        for (uint256 i = 0; i < withdrawAmounts.length; i++) {
            assertEq(
                withdrawAmounts[i].asset.balanceOf(address(this)) - balances[i],
                withdrawAmounts[i].value
            );
        }
    }

    function test_withdraw_increases_fees() public {
        address feeRecipient = address(1);
        vault.setGuardianAndFeeRecipient(_USER, feeRecipient);

        assertEq(vault.feeTotal(), 0);
        assertEq(vault.fees(feeRecipient), 0);

        skip(1000);

        test_withdraw_success();

        assertEq(vault.feeTotal(), 499999);
        assertEq(vault.fees(feeRecipient), 499999);
    }
}
