// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {TestBase} from "test/utils/TestBase.sol";
import {CurveOracle} from "periphery/CurveOracle.sol";

contract TestBaseCurveOracle is TestBase {
    address internal constant _CURVE_TETH_POOL =
        0x752eBeb79963cf0732E9c0fec72a49FD1DEfAEAC;

    CurveOracle public oracle;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_NODE_URI_MAINNET"), 17642400);

        oracle = new CurveOracle(_CURVE_TETH_POOL);
    }
}
