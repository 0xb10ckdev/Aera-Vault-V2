// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC20Mock} from "../../../../utils/ERC20Mock.sol";
import "../TestBaseExecution.sol";

abstract contract BaseSweepTest is TestBaseExecution {
    function test_sweep_success() public virtual {
        IERC20 erc20 = IERC20(
            address(new ERC20Mock("Token", "TOKEN", 18, 1e30))
        );
        deal(address(erc20), _USER, 10e18);

        vm.prank(_USER);
        erc20.transfer(address(execution), 10e18);

        uint256 balance = erc20.balanceOf(address(this));

        vm.expectEmit(true, true, true, true, address(execution));
        emit Sweep(erc20, _ONE);

        execution.sweep(erc20, _ONE);

        assertEq(erc20.balanceOf(address(this)), balance + _ONE);
    }
}
