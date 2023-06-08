// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";
import {IOracleMock} from "test/utils/OracleMock.sol";

contract EndRebalanceEarlyTest is TestBaseAeraVaultV2 {
    function test_endRebalanceEarly_fail_whenCallerIsNotOwnerOrGuardian()
        public
    {
        vm.expectRevert(ICustody.Aera__CallerIsNotOwnerOrGuardian.selector);

        vm.prank(_USER);
        vault.endRebalanceEarly();
    }

    function test_endRebalanceEarly_fail_whenFinalized() public {
        vault.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        vault.endRebalanceEarly();
    }

    function test_endRebalanceEarly_fail_whenVaultIsPaused() public {
        vault.pauseVault();

        vm.expectRevert(bytes("Pausable: paused"));

        vault.endRebalanceEarly();
    }

    function test_endRebalanceEarly_success_whenRebalancingIsOnGoing()
        public
        virtual
    {
        vm.prank(_GUARDIAN);
        _startRebalance(validRequest);

        vm.expectEmit(true, true, true, true, address(vault));
        emit EndRebalanceEarly();

        vault.endRebalanceEarly();
    }

    function test_endRebalanceEarly_success_whenOraclePriceIsInvalid()
        public
        virtual
    {
        vm.prank(_GUARDIAN);
        _startRebalance(validRequest);

        IOracleMock(address(assetsInformation[nonNumeraire].oracle))
            .setLatestAnswer(-1);

        vm.warp(vault.execution().rebalanceEndTime());

        vm.expectEmit(true, true, true, true, address(vault));
        emit EndRebalanceEarly();

        vault.endRebalanceEarly();
    }

    function test_endRebalanceEarly_success() public virtual {
        vm.prank(_GUARDIAN);
        _startRebalance(validRequest);

        vm.warp(vault.execution().rebalanceEndTime());

        vm.expectEmit(true, true, true, true, address(vault));
        emit EndRebalanceEarly();

        vault.endRebalanceEarly();
    }
}
