// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAeraVaultV2.sol";
import "lib/forge-std/src/StdStorage.sol";

contract FinalizeTest is TestBaseAeraVaultV2 {
    using stdStorage for StdStorage;

    function test_finalize_fail_whenCallerIsNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(_USER);
        vault.finalize();
    }

    function test_finalize_fail_whenHooksIsNotSet() public {
        vault.pause();
        vm.store(
            address(vault),
            bytes32(stdstore.target(address(vault)).sig("hooks()").find()),
            bytes32(uint256(0))
        );
        vm.expectRevert(IVault.Aera__HooksIsZeroAddress.selector);
        vault.finalize();
    }

    function test_finalize_fail_whenAlreadyFinalized() public {
        vault.finalize();

        vm.expectRevert(IVault.Aera__VaultIsFinalized.selector);

        vault.finalize();
    }

    function test_finalize_success_whenOraclePriceIsInvalid() public {
        vault.execute(
            Operation({
                target: address(erc20Assets[0]),
                value: 0,
                data: abi.encodeWithSignature(
                    "transfer(address,uint256)", address(this), 1
                    )
            })
        );

        AssetValue[] memory withdrawnAmounts = vault.holdings();
        _setInvalidOracle(nonNumeraireId);

        vm.expectEmit(true, true, true, true, address(vault));
        emit Finalized(address(this), withdrawnAmounts);

        vault.finalize();
    }

    function test_finalize_success() public virtual {
        vault.execute(
            Operation({
                target: address(erc20Assets[0]),
                value: 0,
                data: abi.encodeWithSignature(
                    "transfer(address,uint256)", address(this), 1
                    )
            })
        );

        AssetValue[] memory holdings = vault.holdings();
        uint256[] memory balances = new uint256[](holdings.length);

        for (uint256 i = 0; i < holdings.length; i++) {
            balances[i] = holdings[i].asset.balanceOf(address(this));
        }

        skip(1000);

        uint256 expectedFeeTotal = 499999;
        AssetValue[] memory expectedWithdrawnAssets = vault.holdings();
        for (uint256 i = 0; i < holdings.length; i++) {
            if (holdings[i].asset == assetRegistry.feeToken()) {
                expectedWithdrawnAssets[i].value -= expectedFeeTotal;
            }
        }
        vm.expectEmit(true, true, true, true, address(vault));
        emit Finalized(address(this), expectedWithdrawnAssets);

        vault.finalize();

        assertEq(vault.feeTotal(), expectedFeeTotal);
        assertEq(vault.fees(_FEE_RECIPIENT), expectedFeeTotal);

        for (uint256 i = 0; i < holdings.length; i++) {
            assertEq(
                balances[i] + holdings[i].value
                    - (
                        holdings[i].asset == assetRegistry.feeToken()
                            ? vault.feeTotal()
                            : 0
                    ),
                holdings[i].asset.balanceOf(address(this))
            );
        }
    }
}
