// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseExecution.sol";

abstract contract BaseSweepTest is TestBaseExecution {
    IERC20 erc20;

    event Sweep(IERC20 erc20);

    function test_sweep_success() public virtual {
        vm.prank(_USER);
        erc20.transfer(address(execution), 10e18);

        uint256 balance = erc20.balanceOf(address(this));

        vm.expectEmit(true, true, true, true, address(execution));
        emit Sweep(erc20);

        execution.sweep(erc20);

        assertEq(erc20.balanceOf(address(this)), balance + 10e18);
    }
}
