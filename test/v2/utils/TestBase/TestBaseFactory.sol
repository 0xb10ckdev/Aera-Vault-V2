// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "src/v2/AeraV2Factory.sol";
import "src/v2/AeraVaultModulesFactory.sol";
import {TestBase} from "test/utils/TestBase.sol";
import {WrappedNativeMock} from "test/utils/WrappedNativeMock.sol";

contract TestBaseFactory is TestBase {
    address internal constant _WETH_ADDRESS =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    AeraV2Factory public factory;
    AeraVaultModulesFactory public modulesFactory;

    function setUp() public virtual {
        _deployAeraV2Factory();
    }

    function _deployAeraV2Factory() internal {
        if (_WETH_ADDRESS.code.length == 0) {
            address weth = address(new WrappedNativeMock());
            vm.etch(_WETH_ADDRESS, weth.code);
        }

        factory = new AeraV2Factory(_WETH_ADDRESS);
        modulesFactory = new AeraVaultModulesFactory(address(factory));
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
