// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAeraVaultV2.sol";
import "lib/forge-std/src/StdStorage.sol";

contract FinalizeTest is TestBaseAeraVaultV2 {
    using stdStorage for StdStorage;

    function test_finalize_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

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
        vm.expectRevert(ICustody.Aera__HooksIsZeroAddress.selector);
        vault.finalize();
    }

    function test_finalize_fail_whenAlreadyFinalized() public {
        vault.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

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

        _setInvalidOracle(nonNumeraireId);

        vm.expectEmit(true, true, true, true, address(vault));
        emit Finalized();

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

        vm.expectEmit(true, true, true, true, address(vault));
        emit Finalized();

        vault.finalize();

        assertEq(vault.feeTotal(), 499999);
        assertEq(vault.fees(_FEE_RECIPIENT), 499999);

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
