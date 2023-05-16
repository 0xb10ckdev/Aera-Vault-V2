// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {TestBaseBalancer} from "../utils/TestBase/TestBaseBalancer.sol";
import "../../../src/v2/AeraBalancerExecution.sol";
import "../../../src/v2/interfaces/IBalancerExecution.sol";
import "../../../src/v2/interfaces/IBalancerExecutionEvents.sol";
import "../utils/TestBaseExecution/TestBaseExecution.sol";

contract TestBaseBalancerExecution is
    TestBaseBalancer,
    TestBaseExecution,
    IBalancerExecutionEvents
{
    function setUp() public virtual override {
        super.setUp();

        for (uint256 i = 0; i < 3; i++) {
            erc20Assets[i].approve(address(balancerExecution), 1);
        }

        balancerExecution.initialize(address(this));

        execution = IExecution(address(balancerExecution));
    }

    function _generateRequestWith2Assets()
        internal
        view
        returns (IExecution.AssetRebalanceRequest[] memory requests)
    {
        requests = new IExecution.AssetRebalanceRequest[](2);

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
    }

    function _generateRequestWith3Assets()
        internal
        view
        returns (IExecution.AssetRebalanceRequest[] memory requests)
    {
        requests = new IExecution.AssetRebalanceRequest[](3);

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
    }

    function _startRebalance(
        IExecution.AssetRebalanceRequest[] memory requests
    ) internal {
        for (uint256 i = 0; i < requests.length; i++) {
            requests[i].asset.approve(
                address(balancerExecution),
                type(uint256).max
            );
        }

        uint256 startTime = block.timestamp + 10;
        uint256 endTime = startTime + 10000;

        vm.expectEmit(true, true, true, true, address(balancerExecution));
        emit StartRebalance(requests, startTime, endTime);

        balancerExecution.startRebalance(requests, startTime, endTime);
    }
}
