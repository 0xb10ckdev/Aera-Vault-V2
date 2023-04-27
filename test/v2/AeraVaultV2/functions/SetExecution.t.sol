// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../../utils/TestBaseCustody/functions/SetExecution.sol";
import "../TestBaseAeraVaultV2.sol";

contract SetExecutionTest is BaseSetExecutionTest, TestBaseAeraVaultV2 {
    function setUp() public override {
        super.setUp();

        newExecution = new AeraBalancerExecution(_generateVaultParams());
    }
}
