// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../TestBaseBalancerExecution.sol";

contract DeploymentTest is TestBaseBalancerExecution {
    function setUp() public override {
        vm.createSelectFork(vm.envString("ETH_NODE_URI_MAINNET"), 16826100);

        _init();

        _deployBalancerManagedPoolFactory();
    }

    function test_balancerExecutionDeployment_fail_whenAssetRegistryIsZeroAddress()
        public
    {
        vm.expectRevert(
            AeraBalancerExecution.Aera__AssetRegistryIsZeroAddress.selector
        );
        new AeraBalancerExecution(_generateVaultParams());
    }

    function test_balancerExecutionDeployment_fail_whenDescriptionIsEmpty()
        public
    {
        _deployAssetRegistry();

        IBalancerExecution.NewVaultParams
            memory vaultParams = _generateVaultParams();
        vaultParams.description = "";

        vm.expectRevert(
            AeraBalancerExecution.Aera__DescriptionIsEmpty.selector
        );
        new AeraBalancerExecution(vaultParams);
    }

    function test_balancerExecutionDeployment_success() public {
        _deployAssetRegistry();

        IBalancerExecution.NewVaultParams
            memory vaultParams = _generateVaultParams();
        balancerExecution = new AeraBalancerExecution(vaultParams);

        assertEq(balancerExecution.description(), vaultParams.description);
        assertEq(
            address(balancerExecution.assetRegistry()),
            address(assetRegistry)
        );
    }
}
