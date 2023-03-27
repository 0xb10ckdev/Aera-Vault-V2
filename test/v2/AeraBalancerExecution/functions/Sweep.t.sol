// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../TestBaseBalancerExecution.sol";
import {ERC20Mock} from "../../../utils/ERC20Mock.sol";

contract SweepTest is TestBaseBalancerExecution {
    IERC20 erc20;

    event Sweep(IERC20 erc20);

    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_NODE_URI_MAINNET"), 16826100);

        _init();

        _deployAssetRegistry();
        _deployBalancerManagedPoolFactory();
        _deployBalancerExecution();

        for (uint256 i = 0; i < 3; i++) {
            erc20Assets[i].approve(address(balancerExecution), 1);
        }

        balancerExecution.initialize(address(this));

        erc20 = IERC20(address(new ERC20Mock("Token", "TOKEN", 18, 1e30)));
        deal(address(erc20), _USER, 10e18);
    }

    function test_sweep_fail_whenCallerIsNotOwner() public {
        vm.startPrank(_USER);

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        balancerExecution.sweep(erc20);
    }

    function test_sweep_fail_whenCannotSweepPoolAsset() public {
        vm.expectRevert(
            AeraBalancerExecution.Aera__CannotSweepPoolAsset.selector
        );
        balancerExecution.sweep(assets[0].asset);
    }

    function test_sweep_success() public {
        _startRebalance(_generateRequestWith3Assets());

        vm.prank(_USER);
        erc20.transfer(address(balancerExecution), 10e18);

        uint256 balance = erc20.balanceOf(address(this));

        vm.expectEmit(true, true, true, true, address(balancerExecution));
        emit Sweep(erc20);

        balancerExecution.sweep(erc20);

        assertEq(erc20.balanceOf(address(this)), balance + 10e18);
    }
}
