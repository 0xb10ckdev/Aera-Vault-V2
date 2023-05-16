// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {TestBaseBalancer} from "../utils/TestBase/TestBaseBalancer.sol";
import "../../../src/v2/AeraVaultV2.sol";
import "../utils/TestBaseCustody/TestBaseCustody.sol";

contract TestBaseAeraVaultV2 is TestBaseBalancer, TestBaseCustody {
    AeraVaultV2 vault;

    function setUp() public virtual override {
        super.setUp();

        _deployAeraVaultV2();

        for (uint256 i = 0; i < erc20Assets.length; i++) {
            erc20Assets[i].approve(address(balancerExecution), 1);
        }
        for (uint256 i = 0; i < assets.length; i++) {
            assets[i].approve(
                address(vault),
                1_000_000 * _getScaler(assets[i])
            );
        }

        balancerExecution.initialize(address(vault));

        custody = ICustody(address(vault));

        _deposit();
    }

    function _deployAeraVaultV2() internal {
        vault = new AeraVaultV2(
            address(assetRegistry),
            address(balancerExecution),
            _GUARDIAN,
            _MAX_GUARDIAN_FEE,
            _getScaler(assets[numeraire]),
            _getScaler(assets[numeraire])
        );
    }

    function _generateValidRequest()
        internal
        view
        returns (ICustody.AssetValue[] memory requests)
    {
        requests = new ICustody.AssetValue[](assets.length);

        for (uint256 i = 0; i < assets.length; i++) {
            requests[i] = ICustody.AssetValue({
                asset: assets[i],
                value: 0.2e18
            });
        }
    }

    function _deposit() internal {
        ICustody.AssetValue[] memory amounts = new ICustody.AssetValue[](
            assets.length
        );

        for (uint256 i = 0; i < assets.length; i++) {
            amounts[i] = ICustody.AssetValue({
                asset: assets[i],
                value: (1_000_00e6 / oraclePrices[i]) * _getScaler(assets[i])
            });
        }

        vault.deposit(amounts);
    }

    function _startRebalance(ICustody.AssetValue[] memory requests) internal {
        uint256 startTime = block.timestamp + 10;
        uint256 endTime = startTime + 10000;

        vm.expectEmit(true, true, true, true, address(custody));
        emit StartRebalance(requests, startTime, endTime);

        custody.startRebalance(requests, startTime, endTime);
    }

    function _normalizeWeights(
        uint256[] memory weights
    ) internal pure returns (uint256[] memory newWeights) {
        uint256 numWeights = weights.length;
        newWeights = new uint256[](numWeights);

        uint256 weightSum;
        for (uint256 i = 0; i < numWeights; i++) {
            weightSum += weights[i];
        }

        if (weightSum == _ONE) {
            return weights;
        }

        uint256 adjustedSum;
        for (uint256 i = 0; i < numWeights; i++) {
            newWeights[i] = (weights[i] * _ONE) / weightSum;
            adjustedSum += newWeights[i];
        }

        newWeights[0] = newWeights[0] + _ONE - adjustedSum;
    }
}
