// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/IERC20.sol";
import "src/v2/interfaces/ISweepable.sol";
import "src/v2/interfaces/ISweepableEvents.sol";
import {TestBase} from "test/utils/TestBase.sol";
import {ERC20Mock} from "test/utils/ERC20Mock.sol";

abstract contract TestBaseSweepable is TestBase, ISweepableEvents {
    ISweepable sweepable;

    function test_sweep_success_fuzzed(
        uint256 balance,
        uint256 amount
    ) public virtual {
        vm.assume(balance < type(uint256).max - amount);

        IERC20 erc20 = IERC20(
            address(new ERC20Mock("Token", "TOKEN", 18, balance))
        );
        deal(address(erc20), _USER, amount);

        vm.prank(_USER);
        erc20.transfer(address(sweepable), amount);

        vm.expectEmit(true, true, true, true, address(sweepable));
        emit Sweep(erc20, amount);

        sweepable.sweep(erc20, amount);

        assertEq(erc20.balanceOf(address(this)), balance + amount);
    }
}
