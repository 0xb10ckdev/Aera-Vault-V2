// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {TestBaseBalancer} from "../utils/TestBase/TestBaseBalancer.sol";
import "../../../src/v2/interfaces/ICustodyEvents.sol";
import "../../../src/v2/AeraVaultV2Factory.sol";

contract TestBaseAeraVaultV2Factory is TestBaseBalancer, ICustodyEvents {
    AeraVaultV2Factory factory;

    function setUp() public virtual override {
        super.setUp();

        factory = new AeraVaultV2Factory();
    }
}
