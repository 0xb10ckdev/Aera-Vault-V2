// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";

contract TestBase is Test {
    uint256 internal constant _ONE = 1e18;
    address internal constant _USER = address(0xabcdef);

    function _testWithDeployedContracts() internal returns (bool) {
        return vm.envOr("TEST_WITH_DEPLOYED_CONTRACTS", false);
    }
}
