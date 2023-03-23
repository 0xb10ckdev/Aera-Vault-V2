// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../TestBaseBalancerExecution.sol";

contract ClaimNowTest is TestBaseBalancerExecution {
    function test_claimNow_fail_whenCallerIsNotVault() public {
        _startRebalance(_generateRequestWith3Assets());

        vm.startPrank(_USER);

        vm.expectRevert(AeraBalancerExecution.Aera__CallerIsNotVault.selector);
        balancerExecution.claimNow();
    }

    function test_claimNow_success() public {
        _startRebalance(_generateRequestWith3Assets());

        vm.warp(balancerExecution.epochEndTime() - 100);

        _swap(_getTargetAmounts());

        IExecution.AssetValue[] memory holdings = balancerExecution.holdings();
        uint256[] memory balances = new uint256[](holdings.length);

        for (uint256 i = 0; i < holdings.length; i++) {
            balances[i] = holdings[i].asset.balanceOf(address(this));
        }

        balancerExecution.claimNow();

        for (uint256 i = 0; i < holdings.length; i++) {
            assertEq(
                holdings[i].asset.balanceOf(address(this)),
                balances[i] + holdings[i].value
            );
        }
    }
}
