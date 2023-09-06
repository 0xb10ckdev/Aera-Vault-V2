// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAeraVaultV2.sol";
import "lib/forge-std/src/StdStorage.sol";
import {ERC20Mock} from "test/utils/ERC20Mock.sol";
import "src/v2/interfaces/IVaultEvents.sol";

contract DepositTest is TestBaseAeraVaultV2 {
    using stdStorage for StdStorage;

    AssetValue[] public depositAmounts;

    function setUp() public override {
        super.setUp();

        for (uint256 i = 0; i < erc20Assets.length; i++) {
            depositAmounts.push(
                AssetValue(erc20Assets[i], 5 * _getScaler(erc20Assets[i]))
            );
        }
    }

    function test_deposit_fail_whenCallerIsNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(_USER);
        vault.deposit(depositAmounts);
    }

    function test_deposit_fail_whenHooksIsNotSet() public {
        vm.store(
            address(vault),
            bytes32(stdstore.target(address(vault)).sig("hooks()").find()),
            bytes32(uint256(0))
        );
        vm.expectRevert(IVault.Aera__HooksIsZeroAddress.selector);
        vault.deposit(depositAmounts);
    }

    function test_deposit_fail_whenFinalized() public {
        vault.finalize();

        vm.expectRevert(IVault.Aera__VaultIsFinalized.selector);

        vault.deposit(depositAmounts);
    }

    function test_deposit_fail_whenAssetIsNotRegistered() public {
        IERC20 erc20 =
            IERC20(address(new ERC20Mock("Token", "TOKEN", 18, 1e30)));
        depositAmounts[0].asset = erc20;

        vm.expectRevert(
            abi.encodeWithSelector(
                IVault.Aera__AssetIsNotRegistered.selector, erc20
            )
        );

        vault.deposit(depositAmounts);
    }

    function test_deposit_fail_whenAssetIsDuplicated() public {
        depositAmounts[0].asset = depositAmounts[1].asset;

        vm.expectRevert(
            abi.encodeWithSelector(
                IVault.Aera__AmountsOrderIsIncorrect.selector,
                1
            )
        );

        vault.deposit(depositAmounts);
    }

    function test_deposit_success_whenOraclePriceIsInvalid() public {
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

        for (uint256 i = 0; i < depositAmounts.length; i++) {
            vm.expectEmit(true, true, true, true, address(vault));
            emit Deposit(vault.owner(), depositAmounts[i].asset, depositAmounts[i].value);
        }

        vault.deposit(depositAmounts);
    }

    function test_deposit_success() public {
        uint256[] memory balances = new uint256[](depositAmounts.length);
        for (uint256 i = 0; i < depositAmounts.length; i++) {
            balances[i] = depositAmounts[i].asset.balanceOf(address(this));
        }

        for (uint256 i = 0; i < depositAmounts.length; i++) {
            vm.expectEmit(true, true, true, true, address(vault));
            emit Deposit(vault.owner(), depositAmounts[i].asset, depositAmounts[i].value);
        }

        vault.deposit(depositAmounts);

        for (uint256 i = 0; i < depositAmounts.length; i++) {
            assertEq(
                balances[i] - depositAmounts[i].asset.balanceOf(address(this)),
                depositAmounts[i].value
            );
        }
    }

    function test_deposit_increases_fees() public {
        address feeRecipient = address(1);
        vault.setGuardianAndFeeRecipient(_USER, feeRecipient);

        assertEq(vault.feeTotal(), 0);
        assertEq(vault.fees(feeRecipient), 0);

        skip(1000);

        test_deposit_success();

        assertEq(vault.feeTotal(), 499999);
        assertEq(vault.fees(feeRecipient), 499999);
    }
}
