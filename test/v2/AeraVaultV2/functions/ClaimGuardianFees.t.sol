// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";

contract ClaimGuardianFeesTest is TestBaseAeraVaultV2 {
    function test_claimGuardianFees_fail_whenNoAvailableFeeForCaller()
        public
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__NoAvailableFeeForCaller.selector, _USER
            )
        );

        vm.prank(_USER);
        vault.claimGuardianFees();
    }

    function test_claimGuardianFees_success() public virtual {
        vm.startPrank(_GUARDIAN);

        vm.warp(block.timestamp + 1000);
        _startRebalance(validRequest);

        vm.stopPrank();

        ICustody.AssetValue[] memory holdings = vault.holdings();
        uint256 fee = vault.guardiansFee(_FEE_RECIPIENT);
        uint256 feeTotal = vault.guardiansFeeTotal();

        uint256[] memory balances = new uint256[](holdings.length);

        for (uint256 i = 0; i < holdings.length; i++) {
            balances[i] = holdings[i].asset.balanceOf(_FEE_RECIPIENT);
        }

        vm.startPrank(_FEE_RECIPIENT);

        vm.expectEmit(true, true, true, true, address(vault));
        emit ClaimGuardianFees(_FEE_RECIPIENT, fee);

        vault.claimGuardianFees();

        assertEq(feeTotal - fee, vault.guardiansFeeTotal());

        for (uint256 i = 0; i < holdings.length; i++) {
            if (holdings[i].asset == feeToken) {
                assertEq(
                    balances[i] + fee,
                    holdings[i].asset.balanceOf(_FEE_RECIPIENT)
                );
            } else {
                assertEq(
                    balances[i], holdings[i].asset.balanceOf(_FEE_RECIPIENT)
                );
            }
        }
    }
}
