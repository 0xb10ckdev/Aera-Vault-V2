// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC20Mock} from "../../../../utils/ERC20Mock.sol";
import "../TestBaseCustody.sol";

abstract contract BaseSweepTest is TestBaseCustody {
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
        erc20.transfer(address(custody), amount);

        vm.expectEmit(true, true, true, true, address(custody));
        emit Sweep(erc20, amount);

        custody.sweep(erc20, amount);

        assertEq(erc20.balanceOf(address(this)), balance + amount);
    }
}
