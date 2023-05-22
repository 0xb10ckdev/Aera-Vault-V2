// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseCustody.sol";

interface ILastFeeCheckpoint {
    function lastFeeCheckpoint() external view returns (uint256 checkpoint);
}

interface IGuardiansFeeTotal {
    function guardiansFeeTotal(
        address asset
    ) external view returns (uint256 fee);
}

abstract contract BaseFinalizeTest is TestBaseCustody {
    function test_finalize_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        custody.finalize();
    }

    function test_finalize_fail_whenAlreadyFinalized() public {
        custody.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        custody.finalize();
    }

    function test_finalize_success_whenRebalancingIsOnGoing() public virtual {
        vm.prank(custody.guardian());
        _startRebalance();

        ICustody.AssetValue[] memory holdings = custody.holdings();
        uint256[] memory balances = new uint256[](holdings.length);

        for (uint256 i = 0; i < holdings.length; i++) {
            balances[i] = holdings[i].asset.balanceOf(address(this));
        }

        vm.expectEmit(true, true, true, true, address(custody));
        emit Finalized();

        custody.finalize();

        for (uint256 i = 0; i < holdings.length; i++) {
            assertEq(
                balances[i] + holdings[i].value,
                holdings[i].asset.balanceOf(address(this))
            );
        }
    }

    function test_finalize_success() public virtual {
        vm.prank(custody.guardian());
        _startRebalance();

        vm.warp(custody.execution().rebalanceEndTime());

        uint256 lastFeeCheckpoint = ILastFeeCheckpoint(address(custody))
            .lastFeeCheckpoint();

        ICustody.AssetValue[] memory holdings = custody.holdings();
        uint256[] memory balances = new uint256[](holdings.length);

        for (uint256 i = 0; i < holdings.length; i++) {
            balances[i] = holdings[i].asset.balanceOf(address(this));
        }

        vm.expectEmit(true, true, true, true, address(custody));
        emit Finalized();

        custody.finalize();

        for (uint256 i = 0; i < holdings.length; i++) {
            assertApproxEqRel(
                balances[i] + holdings[i].value,
                holdings[i].asset.balanceOf(address(this)),
                custody.guardianFee() * (block.timestamp - lastFeeCheckpoint)
            );
        }
    }
}
