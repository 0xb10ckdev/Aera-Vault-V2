// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "src/v2/AeraVaultAssetRegistry.sol";
import "src/v2/AeraVaultHooks.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/interfaces/IHooksEvents.sol";
import {TestBaseCustody} from "test/v2/utils/TestBase/TestBaseCustody.sol";

contract TestBaseAeraVaultHooks is TestBaseCustody, IHooksEvents {
    function setUp() public virtual override {
        super.setUp();

        if (_testWithDeployedContracts()) {
            (,,, address deployedHooks) = _loadDeployedAddresses();

            hooks = AeraVaultHooks(deployedHooks);
            vault = AeraVaultV2(payable(address(hooks.custody())));
            assetRegistry =
                AeraVaultAssetRegistry(address(vault.assetRegistry()));

            _updateOwnership();
            _loadParameters();
        }
    }
}
