// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseCustody.sol";
import {ERC20Mock} from "test/utils/ERC20Mock.sol";

abstract contract BaseStartRebalanceTest is TestBaseCustody {
    function test_startRebalance_fail_whenCallerIsNotGuardian() public {
        vm.expectRevert(ICustody.Aera__CallerIsNotGuardian.selector);

        vm.prank(_USER);
        _startRebalance();
    }

    function test_startRebalance_fail_whenFinalized() public {
        custody.finalize();

        vm.startPrank(custody.guardian());

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        _startRebalance();
    }

    function test_startRebalance_fail_whenVaultIsPaused() public {
        custody.pauseVault();

        vm.startPrank(custody.guardian());

        vm.expectRevert(bytes("Pausable: paused"));

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

    function test_startRebalance_fail_whenValueLengthIsNotSame() public {
        ICustody.AssetValue[] memory requests = _generateRequest();
        ICustody.AssetValue[]
            memory invalidRequests = new ICustody.AssetValue[](
                requests.length - 1
            );

        for (uint256 i = 0; i < requests.length - 1; i++) {
            invalidRequests[i] = requests[i];
        }

        vm.startPrank(custody.guardian());

        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__ValueLengthIsNotSame.selector,
                custody.assetRegistry().assets().length,
                invalidRequests.length
            )
        );

        custody.startRebalance(
            invalidRequests,
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

    function test_startRebalance_fail_whenAssetIsDuplicated() public {
        ICustody.AssetValue[] memory requests = _generateRequest();
        requests[0].asset = requests[1].asset;

        vm.startPrank(custody.guardian());

        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__AssetIsDuplicated.selector,
                requests[0].asset
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
