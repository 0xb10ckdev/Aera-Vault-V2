// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseWstETHOracle.sol";

contract DeploymentTest is TestBaseWstETHOracle {
    function test_wstETHOracleDeployment_fail_whenWstETHIsZeroAddress()
        public
    {
        vm.expectRevert(
            WstETHOracle.AeraPeriphery__WstETHIsZeroAddress.selector
        );
        new WstETHOracle(address(0));
    }

    function test_wstETHOracleDeployment_fail_whenWstETHIsNotContract()
        public
    {
        vm.expectRevert(WstETHOracle.AeraPeriphery__InvalidWstETH.selector);
        new WstETHOracle(address(1));
    }

    function test_wstETHOracleDeployment_fail_whenWstETHIsInvalid() public {
        vm.expectRevert(WstETHOracle.AeraPeriphery__InvalidWstETH.selector);
        new WstETHOracle(address(this));
    }

    function test_wstETHOracleDeployment_success() public {
        oracle = new WstETHOracle(_WSTETH_ADDRESS);

        assertEq(address(oracle.wstETH()), _WSTETH_ADDRESS);
        assertEq(oracle.decimals(), 18);
    }
}
