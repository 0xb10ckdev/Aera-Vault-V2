// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "src/v2/AeraVaultV2Factory.sol";
import {TestBase} from "test/utils/TestBase.sol";

contract TestBaseFactory is TestBase {
    AeraVaultV2Factory public factory;

    function setUp() public virtual {
        _deployAeraVaultV2Factory();
    }

    function _deployAeraVaultV2Factory() internal {
        factory = new AeraVaultV2Factory();
    }

    function _loadDeployedFactory()
        internal
        returns (address deployedFactory)
    {
        string memory path =
            string.concat(vm.projectRoot(), "/config/Deployments.json");
        string memory json = vm.readFile(path);

        deployedFactory = vm.parseJsonAddress(json, ".factory");
    }
}
