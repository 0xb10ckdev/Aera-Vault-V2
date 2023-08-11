// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "src/v2/AeraVaultAssetRegistry.sol";
import "src/v2/AeraVaultHooks.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/interfaces/ICustodyEvents.sol";
import {TestBaseCustody} from "test/v2/utils/TestBase/TestBaseCustody.sol";
import {OracleMock} from "test/utils/OracleMock.sol";

contract TestBaseAeraVaultV2 is TestBaseCustody, ICustodyEvents {
    function setUp() public virtual override {
        super.setUp();

        if (_testWithDeployedContracts()) {
            (,, address deployedCustody,) = _loadDeployedAddresses();

            vault = AeraVaultV2(payable(deployedCustody));
            assetRegistry =
                AeraVaultAssetRegistry(address(vault.assetRegistry()));
            hooks = AeraVaultHooks(address(vault.hooks()));

            _updateOwnership();
            _loadParameters();
        }

        for (uint256 i = 0; i < assets.length; i++) {
            assets[i].approve(
                address(vault), 1_000_000 * _getScaler(assets[i])
            );
        }

        vm.warp(block.timestamp + 1000);

        _deposit();
        vault.resume();
    }

    function _deposit() internal {
        AssetValue[] memory amounts = new AssetValue[](assets.length);

        for (uint256 i = 0; i < assets.length; i++) {
            amounts[i] = AssetValue({
                asset: assets[i],
                value: 1_000_00e6 * _getScaler(assets[i]) / oraclePrices[i]
            });
        }

        vault.deposit(amounts);
    }

    function _setInvalidOracle(uint256 index) internal {
        deployCodeTo(
            "OracleMock.sol",
            abi.encode(6),
            address(assetsInformation[index].oracle)
        );
        OracleMock(address(assetsInformation[index].oracle)).setLatestAnswer(
            -1
        );
    }
}
