// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../../utils/TestBaseExecution/functions/ClaimNow.sol";
import "../TestBaseBalancerExecution.sol";

contract ClaimNowTest is BaseClaimNowTest, TestBaseBalancerExecution {
    event ClaimNow();

    function test_claimNow_success() public {
        _startRebalance(_generateRequestWith3Assets());

        vm.warp(balancerExecution.epochEndTime() - 100);

        _swap(_getTargetAmounts());

        IExecution.AssetValue[] memory holdings = balancerExecution.holdings();
        uint256[] memory balances = new uint256[](holdings.length);

        for (uint256 i = 0; i < holdings.length; i++) {
            balances[i] = holdings[i].asset.balanceOf(address(this));
        }

        vm.expectEmit(true, true, true, true, address(balancerExecution));
        emit ClaimNow();

        balancerExecution.claimNow();

        for (uint256 i = 0; i < holdings.length; i++) {
            assertEq(
                holdings[i].asset.balanceOf(address(this)),
                balances[i] + holdings[i].value
            );
        }
    }
}
