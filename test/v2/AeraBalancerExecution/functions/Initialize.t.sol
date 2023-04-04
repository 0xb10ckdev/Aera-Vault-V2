// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseBalancerExecution.sol";

contract InitializeTest is TestBaseBalancerExecution {
    event Initialize(address vault);

    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_NODE_URI_MAINNET"), 16826100);

        _init();

        _deployAssetRegistry();
        _deployBalancerManagedPoolFactory();
        _deployBalancerExecution();
    }

    function test_initialize_fail_whenModuleIsAlreadyInitialized() public {
        for (uint256 i = 0; i < 3; i++) {
            erc20Assets[i].approve(address(balancerExecution), 1);
        }

        balancerExecution.initialize(address(this));

        vm.expectRevert(
            AeraBalancerExecution.Aera__ModuleIsAlreadyInitialized.selector
        );
        balancerExecution.initialize(address(this));
    }

    function test_initialize_fail_whenVaultIsZeroAddress() public {
        vm.expectRevert(
            AeraBalancerExecution.Aera__VaultIsZeroAddress.selector
        );
        balancerExecution.initialize(address(0));
    }

    function test_initialize_fail_whenCallerIsNotOwner() public {
        vm.startPrank(_USER);

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        balancerExecution.initialize(address(this));
    }

    function test_initialize_success() public {
        for (uint256 i = 0; i < 3; i++) {
            erc20Assets[i].approve(address(balancerExecution), 1);
        }

        vm.expectEmit(true, true, true, true, address(balancerExecution));
        emit Initialize(address(this));

        balancerExecution.initialize(address(this));
    }
}
