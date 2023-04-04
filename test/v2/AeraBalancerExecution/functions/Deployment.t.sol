// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseBalancerExecution.sol";
import {ERC20Mock} from "../../../utils/ERC20Mock.sol";

contract DeploymentTest is TestBaseBalancerExecution {
    function test_balancerExecutionDeployment_fail_whenAssetRegistryIsZeroAddress()
        public
    {
        IBalancerExecution.NewBalancerExecutionParams
            memory vaultParams = _generateVaultParams();
        vaultParams.assetRegistry = address(0);

        vm.expectRevert(
            AeraBalancerExecution.Aera__AssetRegistryIsZeroAddress.selector
        );
        new AeraBalancerExecution(vaultParams);
    }

    function test_balancerExecutionDeployment_fail_whenDescriptionIsEmpty()
        public
    {
        IBalancerExecution.NewBalancerExecutionParams
            memory vaultParams = _generateVaultParams();
        vaultParams.description = "";

        vm.expectRevert(
            AeraBalancerExecution.Aera__DescriptionIsEmpty.selector
        );
        new AeraBalancerExecution(vaultParams);
    }

    function test_balancerExecutionDeployment__fail_whenPoolTokenIsNotRegistered()
        public
    {
        IERC20 erc20 = IERC20(
            address(new ERC20Mock("Token", "TOKEN", 18, 1e30))
        );

        IBalancerExecution.NewBalancerExecutionParams
            memory vaultParams = _generateVaultParams();
        vaultParams.poolTokens[0] = erc20;

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraBalancerExecution.Aera__PoolTokenIsNotRegistered.selector,
                erc20
            )
        );
        new AeraBalancerExecution(vaultParams);
    }

    function test_balancerExecutionDeployment_success() public {
        IBalancerExecution.NewBalancerExecutionParams
            memory vaultParams = _generateVaultParams();
        balancerExecution = new AeraBalancerExecution(vaultParams);

        assertEq(balancerExecution.description(), vaultParams.description);
        assertEq(
            address(balancerExecution.assetRegistry()),
            address(assetRegistry)
        );
    }
}
