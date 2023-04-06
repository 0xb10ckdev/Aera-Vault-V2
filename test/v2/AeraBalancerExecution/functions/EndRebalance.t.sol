// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../../utils/TestBaseExecution/functions/EndRebalance.sol";
import "../TestBaseBalancerExecution.sol";

contract EndRebalanceTest is BaseEndRebalanceTest, TestBaseBalancerExecution {
    function test_endRebalance_success() public {
        _startRebalance(_generateRequestWith3Assets());

        vm.warp(balancerExecution.rebalanceEndTime());

        _swap(_getTargetAmounts());

        IExecution.AssetValue[] memory holdings = balancerExecution.holdings();
        uint256[] memory balances = new uint256[](holdings.length);

        for (uint256 i = 0; i < holdings.length; i++) {
            balances[i] = holdings[i].asset.balanceOf(address(this));
        }

        vm.expectEmit(true, true, true, true, address(balancerExecution));
        emit EndRebalance();

        balancerExecution.endRebalance();

        for (uint256 i = 0; i < holdings.length; i++) {
            assertEq(
                holdings[i].asset.balanceOf(address(this)),
                balances[i] + holdings[i].value
            );
        }
    }

    function _generateRequest()
        internal
        override
        returns (IExecution.AssetRebalanceRequest[] memory requests)
    {
        return _generateRequestWith2Assets();
    }
}
