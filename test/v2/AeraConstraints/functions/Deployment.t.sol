// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseConstraints.sol";
import "src/v2/AeraConstraints.sol";

contract DeploymentTest is TestBaseConstraints {
    function test_constraintsDeployment_fail_whenAssetRegistryIsZeroAddress()
        public
    {
        vm.expectRevert(IConstraints.Aera__AssetRegistryIsZeroAddress.selector);
        new AeraConstraints(address(0));
    }

    function test_constraintsDeployment_fail_whenAssetRegistryIsNotValid()
        public
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                IConstraints.Aera__AssetRegistryIsNotValid.selector, address(1)
            )
        );

        new AeraConstraints(address(1));
    }

    function test_constraintsDeployment_success() public {
        constraints = new AeraConstraints(address(assetRegistry));

        assertEq(address(assetRegistry), address(constraints.assetRegistry()));
    }
}
