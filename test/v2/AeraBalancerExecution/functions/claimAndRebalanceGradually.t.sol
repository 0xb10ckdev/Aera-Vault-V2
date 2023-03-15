// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../TestBaseBalancerExecution.sol";

contract ClaimAndRebalanceGraduallyTest is TestBaseBalancerExecution {
    function test_claimAndRebalanceGradually_with_3_assets_success() public {
        IExecution.AssetRebalanceRequest[]
            memory requests = new IExecution.AssetRebalanceRequest[](3);

        // WBTC
        requests[0] = IExecution.AssetRebalanceRequest({
            asset: erc20Assets[0],
            amount: 5e8,
            weight: 0.34e18
        });
        // USDC
        requests[1] = IExecution.AssetRebalanceRequest({
            asset: erc20Assets[1],
            amount: 80_000e6,
            weight: 0.31e18
        });
        // WETH
        requests[2] = IExecution.AssetRebalanceRequest({
            asset: erc20Assets[2],
            amount: 100e18,
            weight: 0.35e18
        });

        IOracleMock(address(assets[0].oracle)).setLatestAnswer(
            int256(15_000e6)
        );
        IOracleMock(address(assets[2].oracle)).setLatestAnswer(int256(1_000e6));

        for (uint256 i = 0; i < 3; i++) {
            assets[i].asset.approve(
                address(balancerExecution),
                type(uint256).max
            );
        }

        uint256 startTime = block.timestamp + 10;
        uint256 endTime = startTime + 10000;

        balancerExecution.claimAndRebalanceGradually(
            requests,
            startTime,
            endTime
        );

        vm.warp(endTime);

        balancerExecution.claimNow();
    }

    function test_claimAndRebalanceGradually_with_2_assets_success() public {
        IExecution.AssetRebalanceRequest[]
            memory requests = new IExecution.AssetRebalanceRequest[](2);

        // WBTC
        requests[0] = IExecution.AssetRebalanceRequest({
            asset: erc20Assets[0],
            amount: 5e8,
            weight: 0.69e18
        });
        // USDC
        requests[1] = IExecution.AssetRebalanceRequest({
            asset: erc20Assets[1],
            amount: 80_000e6,
            weight: 0.31e18
        });

        IOracleMock(address(assets[0].oracle)).setLatestAnswer(
            int256(15_000e6)
        );
        IOracleMock(address(assets[2].oracle)).setLatestAnswer(int256(1_000e6));

        for (uint256 i = 0; i < 2; i++) {
            assets[i].asset.approve(
                address(balancerExecution),
                type(uint256).max
            );
        }

        uint256 startTime = block.timestamp + 10;
        uint256 endTime = startTime + 10000;
        balancerExecution.claimAndRebalanceGradually(
            requests,
            startTime,
            endTime
        );

        vm.warp(endTime);

        balancerExecution.claimNow();
    }

    function test_claimAndRebalanceGradually_with_3_assets_after_2_assets_success() public {
        test_claimAndRebalanceGradually_with_2_assets_success();
        test_claimAndRebalanceGradually_with_3_assets_success();
    }
}
