// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC20Mock} from "../../../../utils/ERC20Mock.sol";
import "../TestBaseCustody.sol";

interface IGuardiansFee {
    function guardiansFee(
        address guardian,
        uint256 index
    ) external view returns (ICustody.AssetValue memory fee);
}

abstract contract BaseClaimGuardianFeesTest is TestBaseCustody {
    function test_claimGuardianFees_fail_whenNoAvailableFeeForCaller() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__NoAvailableFeeForCaller.selector,
                _USER
            )
        );

        vm.prank(_USER);
        custody.claimGuardianFees();
    }

    function test_claimGuardianFees_success() public virtual {
        address guardian = custody.guardian();

        vm.startPrank(guardian);

        vm.warp(block.timestamp + 1000);
        _startRebalance();

        ICustody.AssetValue[] memory holdings = custody.holdings();
        ICustody.AssetValue[] memory fees = new ICustody.AssetValue[](
            holdings.length
        );

        uint256[] memory balances = new uint256[](holdings.length);

        for (uint256 i = 0; i < holdings.length; i++) {
            fees[i] = IGuardiansFee(address(custody)).guardiansFee(guardian, i);
            balances[i] = holdings[i].asset.balanceOf(guardian);
        }

        vm.expectEmit(true, true, true, true, address(custody));
        emit ClaimGuardianFees(guardian, fees);

        custody.claimGuardianFees();

        for (uint256 i = 0; i < holdings.length; i++) {
            assertEq(
                balances[i] + fees[i].value,
                holdings[i].asset.balanceOf(guardian)
            );
        }
    }
}
