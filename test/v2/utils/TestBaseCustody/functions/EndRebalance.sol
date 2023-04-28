// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC20Mock} from "../../../../utils/ERC20Mock.sol";
import "../TestBaseCustody.sol";

abstract contract BaseEndRebalanceTest is TestBaseCustody {
    function test_endRebalance_fail_whenCallerIsNotOwnerOrGuardian() public {
        vm.expectRevert(ICustody.Aera__CallerIsNotOwnerOrGuardian.selector);

        vm.prank(_USER);
        custody.endRebalance();
    }

    function test_endRebalance_fail_whenVaultIsPaused() public {
        custody.pauseVault();

        vm.expectRevert(ICustody.Aera__VaultIsPaused.selector);

        custody.endRebalance();
    }

    function test_endRebalance_fail_whenRebalancingIsOnGoing() public {
        vm.prank(custody.guardian());
        _startRebalance();

        vm.expectRevert(
            abi.encodeWithSelector(
                IExecution.Aera__RebalancingIsOnGoing.selector,
                custody.execution().rebalanceEndTime()
            )
        );

        custody.endRebalance();
    }

    function test_endRebalance_success() public virtual {
        vm.prank(custody.guardian());
        _startRebalance();

        vm.warp(custody.execution().rebalanceEndTime());

        vm.expectEmit(true, true, true, true, address(custody));
        emit EndRebalance();

        custody.endRebalance();
    }
}
