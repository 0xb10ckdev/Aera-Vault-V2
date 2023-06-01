// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseUniswapV3Execution.sol";
import {ERC20Mock} from "../../../utils/ERC20Mock.sol";

contract DeploymentTest is TestBaseUniswapV3Execution {
    function test_uniswapV3ExecutionDeployment_fail_whenAssetRegistryIsZeroAddress()
        public
    {
        IUniswapV3Execution.NewUniswapV3ExecutionParams
            memory executionParams = _generateExecutionParams();
        executionParams.assetRegistry = address(0);

        vm.expectRevert(
            AeraUniswapV3Execution.Aera__AssetRegistryIsZeroAddress.selector
        );
        new AeraUniswapV3Execution(executionParams);
    }

    function test_uniswapV3ExecutionDeployment_fail_whenDescriptionIsEmpty()
        public
    {
        IUniswapV3Execution.NewUniswapV3ExecutionParams
            memory executionParams = _generateExecutionParams();
        executionParams.description = "";

        vm.expectRevert(
            AeraUniswapV3Execution.Aera__DescriptionIsEmpty.selector
        );
        new AeraUniswapV3Execution(executionParams);
    }

    function test_uniswapV3ExecutionDeployment__fail_whenVehicleIsNotRegistered()
        public
    {
        IERC20 erc20 = IERC20(
            address(new ERC20Mock("Token", "TOKEN", 18, 1e30))
        );

        IUniswapV3Execution.NewUniswapV3ExecutionParams
            memory executionParams = _generateExecutionParams();
        executionParams.vehicle = address(erc20);

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraUniswapV3Execution.Aera__VehicleIsNotRegistered.selector,
                erc20
            )
        );
        new AeraUniswapV3Execution(executionParams);
    }

    function test_uniswapV3ExecutionDeployment_success() public {
        IUniswapV3Execution.NewUniswapV3ExecutionParams
            memory executionParams = _generateExecutionParams();
        uniswapV3Execution = new AeraUniswapV3Execution(executionParams);

        assertEq(uniswapV3Execution.description(), executionParams.description);
        assertEq(
            address(uniswapV3Execution.assetRegistry()),
            address(assetRegistry)
        );
    }
}
