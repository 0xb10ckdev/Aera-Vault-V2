// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";

interface ILastFeeCheckpoint {
    function lastFeeCheckpoint() external view returns (uint256 checkpoint);
}

interface IGuardiansFeeTotal {
    function guardiansFeeTotal(
        address asset
    ) external view returns (uint256 fee);
}

contract FinalizeTest is TestBaseAeraVaultV2 {
    function test_finalize_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        vault.finalize();
    }

    function test_finalize_fail_whenAlreadyFinalized() public {
        vault.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        vault.finalize();
    }

    function test_finalize_success_whenRebalancingIsOnGoing() public virtual {
        vm.prank(vault.guardian());
        _startRebalance(_generateValidRequest());

        ICustody.AssetValue[] memory holdings = vault.holdings();
        uint256[] memory balances = new uint256[](holdings.length);

        for (uint256 i = 0; i < holdings.length; i++) {
            balances[i] = holdings[i].asset.balanceOf(address(this));
        }

        vm.expectEmit(true, true, true, true, address(vault));
        emit Finalized();

        vault.finalize();

        for (uint256 i = 0; i < holdings.length; i++) {
            assertEq(
                balances[i] + holdings[i].value,
                holdings[i].asset.balanceOf(address(this))
            );
        }
    }

    function test_finalize_success() public virtual {
        vm.prank(vault.guardian());
        _startRebalance(_generateValidRequest());

        vm.warp(vault.execution().rebalanceEndTime());

        uint256 lastFeeCheckpoint = ILastFeeCheckpoint(address(vault))
            .lastFeeCheckpoint();

        ICustody.AssetValue[] memory holdings = vault.holdings();
        uint256[] memory balances = new uint256[](holdings.length);

        for (uint256 i = 0; i < holdings.length; i++) {
            balances[i] = holdings[i].asset.balanceOf(address(this));
        }

        vm.expectEmit(true, true, true, true, address(vault));
        emit Finalized();

        vault.finalize();

        for (uint256 i = 0; i < holdings.length; i++) {
            assertApproxEqRel(
                balances[i] + holdings[i].value,
                holdings[i].asset.balanceOf(address(this)),
                vault.guardianFee() * (block.timestamp - lastFeeCheckpoint)
            );
        }
    }
}
