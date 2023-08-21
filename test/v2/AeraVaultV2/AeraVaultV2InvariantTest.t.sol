// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "./TestBaseAeraVaultV2.sol";
import "./handlers/AeraVaultV2Handler.sol";

contract AeraVaultV2InvariantTest is TestBaseAeraVaultV2 {
    AeraVaultV2Handler public handler;

    function setUp() public override {
        super.setUp();

        handler = new AeraVaultV2Handler(vault, hooks);

        targetContract(address(handler));
        targetSender(address(this));
    }
}
