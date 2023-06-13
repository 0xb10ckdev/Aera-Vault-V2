// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";
import {IOracleMock} from "test/utils/OracleMock.sol";

contract PauseVaultTest is TestBaseAeraVaultV2 {
    event Paused(address);

    function test_pauseVault_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        vault.pauseVault();
    }

    function test_pauseVault_fail_whenFinalized() public {
        vault.finalize();

        vm.expectRevert(ICustody.Aera__VaultIsFinalized.selector);

        vault.pauseVault();
    }

    function test_pauseVault_fail_whenVaultIsPaused() public {
        vault.pauseVault();

        vm.expectRevert(bytes("Pausable: paused"));

        vault.pauseVault();
    }

    function test_pauseVault_success_whenOraclePriceIsInvalid()
        public
        virtual
    {
        IOracleMock(address(assetsInformation[nonNumeraire].oracle))
            .setLatestAnswer(-1);

        vm.expectEmit(true, true, true, true, address(vault));
        emit Paused(address(this));

        vault.pauseVault();
    }

    function test_pauseVault_success() public virtual {
        vm.expectEmit(true, true, true, true, address(vault));
        emit Paused(address(this));

        vault.pauseVault();
    }
}
