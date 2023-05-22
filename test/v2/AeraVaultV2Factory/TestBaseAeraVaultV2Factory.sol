// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "src/v2/interfaces/ICustodyEvents.sol";
import "src/v2/AeraVaultV2Factory.sol";
import {TestBaseBalancer} from "test/v2/utils/TestBase/TestBaseBalancer.sol";

contract TestBaseAeraVaultV2Factory is TestBaseBalancer, ICustodyEvents {
    AeraVaultV2Factory factory;

    function setUp() public virtual override {
        super.setUp();

        factory = new AeraVaultV2Factory();
    }
}
