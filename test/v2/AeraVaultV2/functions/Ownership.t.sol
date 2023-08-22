// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAeraVaultV2.sol";

contract OwnershipTest is TestBaseAeraVaultV2 {
    event OwnershipTransferStarted(
        address indexed previousOwner, address indexed newOwner
    );
    event OwnershipTransferred(
        address indexed previousOwner, address indexed newOwner
    );

    function test_transferOwnership_fail_whenCallerIsNotOwner() public {
        vm.expectRevert("Ownable: caller is not the owner");

        vm.prank(_USER);
        vault.transferOwnership(address(1));
    }

    function test_transferOwnership_success() public {
        address currentOwner = vault.owner();
        address newOwner = address(1);

        assertEq(vault.pendingOwner(), address(0));

        vm.expectEmit(true, true, true, true, address(vault));
        emit OwnershipTransferStarted(currentOwner, newOwner);

        vm.prank(currentOwner);
        vault.transferOwnership(newOwner);

        assertEq(vault.owner(), currentOwner);
        assertEq(vault.pendingOwner(), newOwner);
    }

    function test_acceptOwnership_fail_whenCallerIsNotPendingOwner() public {
        address newOwner = address(1);

        vm.prank(vault.owner());
        vault.transferOwnership(newOwner);

        assertEq(vault.pendingOwner(), newOwner);

        vm.expectRevert("Ownable2Step: caller is not the new owner");
        vault.acceptOwnership();
    }

    function test_acceptOwnership_success() public {
        address currentOwner = vault.owner();
        address newOwner = address(1);

        assertEq(vault.pendingOwner(), address(0));

        vm.prank(currentOwner);
        vault.transferOwnership(newOwner);

        assertEq(vault.owner(), currentOwner);
        assertEq(vault.pendingOwner(), newOwner);

        vm.expectEmit(true, true, true, true, address(vault));
        emit OwnershipTransferred(currentOwner, newOwner);

        vm.prank(newOwner);
        vault.acceptOwnership();

        assertEq(vault.owner(), newOwner);
        assertEq(vault.pendingOwner(), address(0));
    }

    function test_renounceOwnership_fail() public {
        vm.prank(vault.owner());

        vm.expectRevert(ICustody.Aera__CanNotRenounceOwnership.selector);
        vault.renounceOwnership();
    }
}
