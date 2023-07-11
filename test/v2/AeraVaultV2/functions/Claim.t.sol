// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";

contract ClaimTest is TestBaseAeraVaultV2 {
    function test_claim_fail_whenNoAvailableFeeForCaller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__NoAvailableFeeForCaller.selector, _USER
            )
        );

        vm.prank(_USER);
        vault.claim();
    }

    function test_claim_success() public {
        vm.warp(block.timestamp + 1000);

        vault.execute(
            Operation({
                target: address(erc20Assets[0]),
                value: 0,
                data: abi.encodeWithSignature(
                    "transfer(address,uint256)", address(this), 1
                    )
            })
        );

        AssetValue[] memory holdings = vault.holdings();
        uint256 fee = vault.fees(_FEE_RECIPIENT);
        uint256 feeTotal = vault.feeTotal();

        uint256[] memory balances = new uint256[](holdings.length);

        for (uint256 i = 0; i < holdings.length; i++) {
            balances[i] = holdings[i].asset.balanceOf(_FEE_RECIPIENT);
        }

        vm.startPrank(_FEE_RECIPIENT);

        vm.expectEmit(true, true, true, true, address(vault));
        emit Claim(_FEE_RECIPIENT, fee);

        vault.claim();

        assertEq(feeTotal - fee, vault.feeTotal());

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
