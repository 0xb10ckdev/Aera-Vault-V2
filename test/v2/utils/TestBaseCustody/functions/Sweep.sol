// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC20Mock} from "../../../../utils/ERC20Mock.sol";
import "../TestBaseCustody.sol";

abstract contract BaseSweepTest is TestBaseCustody {
    function test_sweep_success() public virtual {
        IERC20 erc20 = IERC20(
            address(new ERC20Mock("Token", "TOKEN", 18, 1e30))
        );
        deal(address(erc20), _USER, 10e18);

        vm.prank(_USER);
        erc20.transfer(address(custody), 10e18);

        uint256 balance = erc20.balanceOf(address(this));

        vm.expectEmit(true, true, true, true, address(custody));
        emit Sweep(erc20, _ONE);

        custody.sweep(erc20, _ONE);

        assertEq(erc20.balanceOf(address(this)), balance + _ONE);
    }
}
