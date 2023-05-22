// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";
import "test/v2/utils/TestBaseCustody/functions/SetExecution.sol";

contract SetExecutionTest is BaseSetExecutionTest, TestBaseAeraVaultV2 {
    function setUp() public override {
        super.setUp();

        newExecution = new AeraBalancerExecution(_generateVaultParams());
    }
}
