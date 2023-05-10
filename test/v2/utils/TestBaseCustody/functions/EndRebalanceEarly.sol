// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC20Mock} from "../../../../utils/ERC20Mock.sol";
import "../TestBaseCustody.sol";

abstract contract BaseEndRebalanceEarlyTest is TestBaseCustody {
    function test_endRebalanceEarly_fail_whenCallerIsNotOwnerOrGuardian()
        public
    {
        vm.expectRevert(ICustody.Aera__CallerIsNotOwnerOrGuardian.selector);

        vm.prank(_USER);
        custody.endRebalanceEarly();
    }

    function test_endRebalanceEarly_fail_whenFinalized() public {
        custody.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        custody.endRebalanceEarly();
    }

    function test_endRebalanceEarly_fail_whenVaultIsPaused() public {
        custody.pauseVault();

        vm.expectRevert(bytes("Pausable: paused"));

        custody.endRebalanceEarly();
    }

    function test_endRebalanceEarly_success_whenRebalancingIsOnGoing()
        public
        virtual
    {
        vm.prank(custody.guardian());
        _startRebalance();

        vm.expectEmit(true, true, true, true, address(custody));
        emit EndRebalanceEarly();

        custody.endRebalanceEarly();
    }

    function test_endRebalanceEarly_success() public virtual {
        vm.prank(custody.guardian());
        _startRebalance();

        vm.warp(custody.execution().rebalanceEndTime());

        vm.expectEmit(true, true, true, true, address(custody));
        emit EndRebalanceEarly();

        custody.endRebalanceEarly();
    }
}
