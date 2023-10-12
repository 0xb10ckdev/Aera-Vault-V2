// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseCurveOracle.sol";

contract DeploymentTest is TestBaseCurveOracle {
    function test_curveOracleDeployment_fail_whenPoolIsZeroAddress() public {
        vm.expectRevert(
            CurveOracle.AeraPeriphery__CurvePoolIsZeroAddress.selector
        );
        new CurveOracle(address(0));
    }

    function test_curveOracleDeployment_fail_whenPoolIsNotContract() public {
        vm.expectRevert(CurveOracle.AeraPeriphery__InvalidCurvePool.selector);
        new CurveOracle(address(1));
    }

    function test_curveOracleDeployment_fail_whenPoolIsInvalid() public {
        vm.expectRevert(CurveOracle.AeraPeriphery__InvalidCurvePool.selector);
        new CurveOracle(address(this));
    }

    function test_curveOracleDeployment_success() public {
        oracle = new CurveOracle(_CURVE_TETH_POOL);

        assertEq(address(oracle.pool()), _CURVE_TETH_POOL);
        assertEq(oracle.decimals(), 18);
    }
}
