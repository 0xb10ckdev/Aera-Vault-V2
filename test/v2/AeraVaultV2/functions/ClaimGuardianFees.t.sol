// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";

interface IGuardiansFee {
    function guardiansFee(
        address guardian,
        uint256 index
    ) external view returns (ICustody.AssetValue memory fee);
}

contract ClaimGuardianFeesTest is TestBaseAeraVaultV2 {
    function test_claimGuardianFees_fail_whenNoAvailableFeeForCaller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__NoAvailableFeeForCaller.selector,
                _USER
            )
        );

        vm.prank(_USER);
        vault.claimGuardianFees();
    }

    function test_claimGuardianFees_success() public virtual {
        vm.startPrank(_GUARDIAN);

        vm.warp(block.timestamp + 1000);
        _startRebalance(validRequest);

        ICustody.AssetValue[] memory holdings = vault.holdings();
        ICustody.AssetValue[] memory fees = new ICustody.AssetValue[](
            holdings.length
        );

        uint256[] memory balances = new uint256[](holdings.length);

        for (uint256 i = 0; i < holdings.length; i++) {
            fees[i] = IGuardiansFee(address(vault)).guardiansFee(_GUARDIAN, i);
            balances[i] = holdings[i].asset.balanceOf(_GUARDIAN);
        }

        vm.expectEmit(true, true, true, true, address(vault));
        emit ClaimGuardianFees(_GUARDIAN, fees);

        vault.claimGuardianFees();

        for (uint256 i = 0; i < holdings.length; i++) {
            assertEq(
                balances[i] + fees[i].value,
                holdings[i].asset.balanceOf(_GUARDIAN)
            );
        }
    }
}
