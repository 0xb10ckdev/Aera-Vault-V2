// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "src/v2/AeraV2Factory.sol";
import {TestBase} from "test/utils/TestBase.sol";

contract TestBaseFactory is TestBase {
    address internal constant _WETH_ADDRESS =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    AeraV2Factory public factory;

    function setUp() public virtual {
        _deployAeraV2Factory();
    }

    function _deployAeraV2Factory() internal {
        factory = new AeraV2Factory(_WETH_ADDRESS);
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
