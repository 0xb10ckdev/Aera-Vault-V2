// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {ERC20Mock} from "../../../../utils/ERC20Mock.sol";
import "../TestBaseCustody.sol";

abstract contract BaseStartRebalanceTest is TestBaseCustody {
    function test_startRebalance_fail_whenCallerIsNotGuardian() public {
        vm.expectRevert(ICustody.Aera__CallerIsNotGuardian.selector);

        vm.prank(_USER);
        _startRebalance();
    }

    function test_startRebalance_fail_whenVaultIsPaused() public {
        custody.pauseVault();

        vm.startPrank(custody.guardian());

        vm.expectRevert(ICustody.Aera__VaultIsPaused.selector);

        _startRebalance();
    }

    function test_startRebalance_fail_whenSumOfWeightsIsNotOne() public {
        ICustody.AssetValue[] memory requests = _generateRequest();
        requests[0].value++;

        vm.startPrank(custody.guardian());

        vm.expectRevert(ICustody.Aera__SumOfWeightsIsNotOne.selector);

        custody.startRebalance(
            requests,
            block.timestamp,
            block.timestamp + 100
        );
    }

    function test_startRebalance_fail_whenAssetIsNotRegistered() public {
        IERC20 erc20 = IERC20(
            address(new ERC20Mock("Token", "TOKEN", 18, 1e30))
        );

        ICustody.AssetValue[] memory requests = _generateRequest();
        requests[0].asset = erc20;

        vm.startPrank(custody.guardian());

        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__AssetIsNotRegistered.selector,
                erc20
            )
        );

        custody.startRebalance(
            requests,
            block.timestamp,
            block.timestamp + 100
        );
    }

    function test_startRebalance_success() public virtual {
        ICustody.AssetValue[] memory requests = _generateRequest();

        vm.startPrank(custody.guardian());

        vm.expectEmit(true, true, true, true, address(custody));
        emit StartRebalance(requests, block.timestamp, block.timestamp + 100);

        custody.startRebalance(
            requests,
            block.timestamp,
            block.timestamp + 100
        );
    }
}
