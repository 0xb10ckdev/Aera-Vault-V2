// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAeraVaultV2.sol";

contract ReceiveTest is TestBaseAeraVaultV2 {
    function test_receive_fail_whenCallerIsNotWrappedNativeToken() public {
        deal(address(this), _ONE);

        uint256 balance = address(vault).balance;

        vm.expectRevert(IVault.Aera__NotWrappedNativeTokenContract.selector);
        (, bytes memory data) = address(vault).call{value: 1}("");

        // use data trivially to avoid unused low-level call return value warning
        assertGe(data.length, 0);

        assertEq(address(vault).balance, balance);
    }

    function test_receive_success() public {
        deal(_WETH_ADDRESS, _ONE);

        uint256 balance = address(vault).balance;

        vm.prank(_WETH_ADDRESS);
        (bool success,) = address(vault).call{value: 1}("");
        require(success, "Call failed!");

        assertEq(address(vault).balance, balance + 1);
    }
}
