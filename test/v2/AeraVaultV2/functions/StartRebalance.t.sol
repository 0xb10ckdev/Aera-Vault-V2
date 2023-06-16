// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";
import "src/v2/AeraVaultAssetRegistry.sol";
import {ERC20Mock} from "test/utils/ERC20Mock.sol";
import {IOracleMock} from "test/utils/OracleMock.sol";

interface IERC4626Mock {
    function setMaxDepositAmount(uint256 amount, bool use) external;

    function setMaxWithdrawalAmount(uint256 amount, bool use) external;

    function pause() external;
}

contract StartRebalanceTest is TestBaseAeraVaultV2 {
    function test_startRebalance_fail_whenCallerIsNotGuardian() public {
        vm.prank(_USER);

        vm.expectRevert(ICustody.Aera__CallerIsNotGuardian.selector);
        vault.startRebalance(
            validRequest, block.timestamp, block.timestamp + 100
        );
    }

    function test_startRebalance_fail_whenFinalized() public {
        vault.finalize();

        vm.prank(_GUARDIAN);

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);
        vault.startRebalance(
            validRequest, block.timestamp, block.timestamp + 100
        );
    }

    function test_startRebalance_fail_whenVaultIsPaused() public {
        vault.pauseVault();

        vm.prank(_GUARDIAN);

        vm.expectRevert(bytes("Pausable: paused"));
        vault.startRebalance(
            validRequest, block.timestamp, block.timestamp + 100
        );
    }

    function test_startRebalance_fail_whenSumOfWeightsIsNotOne() public {
        ICustody.AssetValue[] memory requests = validRequest;
        requests[0].value++;

        vm.prank(_GUARDIAN);

        vm.expectRevert(ICustody.Aera__SumOfWeightsIsNotOne.selector);
        vault.startRebalance(requests, block.timestamp, block.timestamp + 100);
    }

    function test_startRebalance_fail_whenValueLengthIsNotSame() public {
        ICustody.AssetValue[] memory invalidRequests =
        new ICustody.AssetValue[](
                validRequest.length - 1
            );

        for (uint256 i = 0; i < validRequest.length - 1; i++) {
            invalidRequests[i] = validRequest[i];
        }

        vm.startPrank(_GUARDIAN);

        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__ValueLengthIsNotSame.selector,
                vault.assetRegistry().assets().length,
                invalidRequests.length
            )
        );

        vault.startRebalance(
            invalidRequests, block.timestamp, block.timestamp + 100
        );
    }

    function test_startRebalance_fail_whenAssetIsNotRegistered() public {
        IERC20 erc20 =
            IERC20(address(new ERC20Mock("Token", "TOKEN", 18, 1e30)));

        ICustody.AssetValue[] memory requests = validRequest;
        requests[0].asset = erc20;

        vm.prank(_GUARDIAN);

        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__AssetIsNotRegistered.selector, erc20
            )
        );

        vault.startRebalance(requests, block.timestamp, block.timestamp + 100);
    }

    function test_startRebalance_fail_whenAssetIsDuplicated() public {
        ICustody.AssetValue[] memory requests = validRequest;
        requests[0].asset = requests[1].asset;

        vm.prank(_GUARDIAN);

        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__AssetIsDuplicated.selector, requests[0].asset
            )
        );

        vault.startRebalance(requests, block.timestamp, block.timestamp + 100);
    }

    function test_startRebalance_fail_whenOraclePriceIsInvalid() public {
        IOracleMock(address(assetsInformation[nonNumeraire].oracle))
            .setLatestAnswer(-1);

        vm.prank(_GUARDIAN);

        vm.warp(block.timestamp + 1000);

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__OraclePriceIsInvalid.selector,
                nonNumeraire,
                -1
            )
        );

        vault.startRebalance(
            validRequest, block.timestamp, block.timestamp + 100
        );
    }

    function test_startRebalance_success_whenNoYieldAssetsShouldBeAdjusted()
        public
    {
        ICustody.AssetValue[] memory requests = validRequest;

        uint256[] memory balances = _getAssetBalances();

        _rebalance(requests);

        uint256[] memory currentBalances = _getAssetBalances();
        uint256[] memory currentWeights = _getAssetWeights();

        for (uint256 i = 0; i < assets.length; i++) {
            if (assetsInformation[i].isERC4626) {
                assertApproxEqRel(balances[i], currentBalances[i], 0.001e18);
            }
            assertApproxEqAbs(requests[i].value, currentWeights[i], 0.05e18);
        }
    }

    function test_startRebalance_success_whenYieldActionAmountIsLessThanThreshold(
    ) public {
        ICustody.AssetValue[] memory requests = validRequest;

        uint256 numERC4626 = yieldAssets.length;
        uint256 index;
        for (uint256 i = 0; i < assets.length; i++) {
            if (assetsInformation[i].isERC4626) {
                if (numERC4626 % 2 == 0 || index < numERC4626 - 1) {
                    if (index % 2 == 0) {
                        requests[i].value += 0.0001e18;
                    } else {
                        requests[i].value -= 0.0001e18;
                    }
                }

                index++;
            }
        }

        uint256[] memory balances = _getAssetBalances();

        _rebalance(requests);

        uint256[] memory currentBalances = _getAssetBalances();
        uint256[] memory currentWeights = _getAssetWeights();

        for (uint256 i = 0; i < assets.length; i++) {
            if (assetsInformation[i].isERC4626) {
                assertApproxEqRel(balances[i], currentBalances[i], 0.001e18);
            }
            assertApproxEqAbs(requests[i].value, currentWeights[i], 0.05e18);
        }
    }

    function test_startRebalance_success_whenYieldAssetsShouldBeAdjusted()
        public
    {
        ICustody.AssetValue[] memory requests = validRequest;

        uint256 numAssets = assets.length;
        for (uint256 i = 0; i < numAssets; i++) {
            if (numAssets % 2 == 0 || i < numAssets - 1) {
                if (i % 2 == 0) {
                    requests[i].value += ((i / 2 + 1) * _ONE) / 100;
                } else {
                    requests[i].value -= ((i / 2 + 1) * _ONE) / 100;
                }
            }
        }

        _rebalance(requests);

        uint256[] memory currentWeights = _getAssetWeights();

        for (uint256 i = 0; i < numAssets; i++) {
            assertApproxEqAbs(requests[i].value, currentWeights[i], 0.05e18);
        }
    }

    function test_startRebalance_success_whenMaxDepositAndWithdrawalAmountIsLimited_fuzzed(
        uint256 maxDeposit,
        uint256 maxWithdrawal
    ) public {
        ICustody.AssetValue[] memory requests = validRequest;

        uint256 numERC4626 = yieldAssets.length;
        uint256 index;
        for (uint256 i = 0; i < assets.length; i++) {
            if (assetsInformation[i].isERC4626) {
                if (numERC4626 % 2 == 0 || index < numERC4626 - 1) {
                    if (index % 2 == 0) {
                        requests[i].value += 0.001e18;
                        IERC4626Mock(address(assets[i])).setMaxDepositAmount(
                            maxDeposit, true
                        );
                    } else {
                        requests[i].value -= 0.001e18;
                        IERC4626Mock(address(assets[i])).setMaxWithdrawalAmount(
                            maxWithdrawal, true
                        );
                    }
                }

                index++;
            }
        }

        uint256[] memory balances = _getAssetBalances();

        _rebalance(requests);

        uint256[] memory currentBalances = _getAssetBalances();
        uint256[] memory currentWeights = _getAssetWeights();

        index = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            if (assetsInformation[i].isERC4626) {
                if ((numERC4626 % 2 == 0 || index < numERC4626 - 1)) {
                    if (index % 2 == 0) {
                        assertApproxEqAbs(
                            balances[i], currentBalances[i], maxDeposit
                        );
                    } else {
                        assertApproxEqAbs(
                            balances[i], currentBalances[i], maxWithdrawal
                        );
                    }
                }
                index++;
            }

            assertApproxEqAbs(requests[i].value, currentWeights[i], 0.05e18);
        }
    }

    function test_startRebalance_success_whenMaxDepositAndWithdrawReverts()
        public
    {
        ICustody.AssetValue[] memory requests = validRequest;

        uint256 numERC4626 = yieldAssets.length;
        uint256 index;
        for (uint256 i = 0; i < assets.length; i++) {
            if (assetsInformation[i].isERC4626) {
                if (numERC4626 % 2 == 0 || index < numERC4626 - 1) {
                    if (index % 2 == 0) {
                        requests[i].value += 0.001e18;
                    } else {
                        requests[i].value -= 0.001e18;
                    }
                    IERC4626Mock(address(assets[i])).pause();
                }

                index++;
            }
        }

        uint256[] memory balances = _getAssetBalances();

        _rebalance(requests);

        uint256[] memory currentBalances = _getAssetBalances();
        uint256[] memory currentWeights = _getAssetWeights();

        index = 0;
        for (uint256 i = 0; i < assets.length; i++) {
            if (assetsInformation[i].isERC4626) {
                if ((numERC4626 % 2 == 0 || index < numERC4626 - 1)) {
                    assertEq(balances[i], currentBalances[i]);
                }
                index++;
            }
            assertApproxEqAbs(requests[i].value, currentWeights[i], 0.05e18);
        }
    }

    function _rebalance(ICustody.AssetValue[] memory requests) internal {
        vm.prank(_GUARDIAN);
        _startRebalance(requests);

        vm.warp(vault.execution().rebalanceEndTime());

        _swap(_getTargetAmounts());

        vault.endRebalance();
    }

    function _getAssetBalances()
        internal
        view
        returns (uint256[] memory balances)
    {
        balances = new uint256[](assets.length);

        for (uint256 i = 0; i < assets.length; i++) {
            balances[i] = assets[i].balanceOf(address(vault));
        }
    }
}
