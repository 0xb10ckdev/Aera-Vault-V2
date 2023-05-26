// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";

contract EndRebalanceTest is TestBaseAeraVaultV2 {
    function test_endRebalance_fail_whenCallerIsNotOwnerOrGuardian() public {
        vm.expectRevert(ICustody.Aera__CallerIsNotOwnerOrGuardian.selector);

        vm.prank(_USER);
        vault.endRebalance();
    }

    function test_endRebalance_fail_whenFinalized() public {
        vault.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        vault.endRebalance();
    }

    function test_endRebalance_fail_whenVaultIsPaused() public {
        vault.pauseVault();

        vm.expectRevert(bytes("Pausable: paused"));

        vault.endRebalance();
    }

    function test_endRebalance_fail_whenRebalancingHasNotStarted() public {
        vm.expectRevert(ICustody.Aera__RebalancingHasNotStarted.selector);
        vault.endRebalance();
    }

    function test_endRebalance_fail_whenRebalancingIsOnGoing() public {
        vm.prank(vault.guardian());
        _startRebalance(_generateValidRequest());

        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__RebalancingIsOnGoing.selector,
                vault.rebalanceEndTime()
            )
        );

        vault.endRebalance();
    }

    function test_endRebalance_success() public virtual {
        vm.prank(vault.guardian());
        _startRebalance(_generateValidRequest());

        vm.warp(vault.execution().rebalanceEndTime());

        vm.expectEmit(true, true, true, true, address(vault));
        emit EndRebalance();

        vault.endRebalance();
    }
}
