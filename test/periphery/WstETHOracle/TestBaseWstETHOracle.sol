// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {TestBase} from "test/utils/TestBase.sol";
import {WstETHOracle} from "periphery/WstETHOracle.sol";

contract TestBaseWstETHOracle is TestBase {
    address internal constant _WSTETH_ADDRESS =
        0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    WstETHOracle public oracle;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_NODE_URI_MAINNET"), 17642400);

        oracle = new WstETHOracle(_WSTETH_ADDRESS);
    }
}
