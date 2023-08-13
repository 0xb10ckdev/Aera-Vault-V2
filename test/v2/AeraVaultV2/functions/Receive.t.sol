// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAeraVaultV2.sol";

contract ReceiveTest is TestBaseAeraVaultV2 {
    function test_receive_fail_whenCallerIsNotWETH() public {
        deal(address(this), _ONE);

        uint256 balance = address(vault).balance;

        vm.expectRevert(ICustody.Aera__NotWETHContract.selector);

        address(vault).call{value: 1}("");

        assertEq(address(vault).balance, balance);
    }

    function test_receive_success() public {
        deal(_WETH_ADDRESS, _ONE);

        uint256 balance = address(vault).balance;

        vm.prank(_WETH_ADDRESS);
        address(vault).call{value: 1}("");

        assertEq(address(vault).balance, balance + 1);
    }
}
