// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAssetRegistry.sol";

contract SweepTest is TestBaseAssetRegistry {
    IERC20 public erc20;

    event Sweep(address token, uint256 amount);

    function setUp() public override {
        super.setUp();

        erc20 = IERC20(address(new ERC20Mock("Token", "TOKEN", 18, 1e30)));
        deal(address(erc20), _USER, 10e18);
    }

    function test_sweep_fail_whenCallerIsNotOwner() public {
        vm.prank(_USER);

        vm.expectRevert("Ownable: caller is not the owner");
        assetRegistry.sweep(address(erc20), 1);
    }

    function test_sweep_success_withETH() public {
        deal(address(assetRegistry), ONE * 2);

        uint256 balance = address(this).balance;
        uint256 assetRegistryBalance = address(assetRegistry).balance;

        vm.expectEmit(true, true, true, true, address(assetRegistry));
        emit Sweep(address(0), ONE);

        assetRegistry.sweep(address(0), ONE);

        assertEq(address(this).balance, balance + ONE);
        assertEq(address(assetRegistry).balance, assetRegistryBalance - ONE);
    }

    function test_sweep_success_withERC20() public {
        vm.prank(_USER);
        erc20.transfer(address(assetRegistry), 10e18);

        uint256 balance = erc20.balanceOf(address(this));
        uint256 assetRegistryBalance = erc20.balanceOf(address(assetRegistry));

        vm.expectEmit(true, true, true, true, address(assetRegistry));
        emit Sweep(address(erc20), 10e18);

        assetRegistry.sweep(address(erc20), 10e18);

        assertEq(erc20.balanceOf(address(this)), balance + 10e18);
        assertEq(
            erc20.balanceOf(address(assetRegistry)),
            assetRegistryBalance - 10e18
        );
    }

    receive() external payable {}
}
