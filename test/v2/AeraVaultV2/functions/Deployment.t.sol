// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";
import {ERC20Mock} from "../../../utils/ERC20Mock.sol";

contract DeploymentTest is TestBaseAeraVaultV2 {
    uint256 yieldActionThreshold;

    function setUp() public override {
        super.setUp();

        yieldActionThreshold = _getScaler(assets[numeraire]);
    }

    function test_aeraVaultV2Deployment_fail_whenAssetRegistryIsZeroAddress()
        public
    {
        vm.expectRevert(ICustody.Aera__AssetRegistryIsZeroAddress.selector);
        new AeraVaultV2(
            address(0),
            address(balancerExecution),
            _GUARDIAN,
            _MAX_GUARDIAN_FEE,
            yieldActionThreshold
        );
    }

    function test_aeraVaultV2Deployment_fail_whenExecutionIsZeroAddress()
        public
    {
        vm.expectRevert(ICustody.Aera__ExecutionIsZeroAddress.selector);
        new AeraVaultV2(
            address(assetRegistry),
            address(0),
            _GUARDIAN,
            _MAX_GUARDIAN_FEE,
            yieldActionThreshold
        );
    }

    function test_aeraVaultV2Deployment_fail_whenGuardianIsZeroAddress()
        public
    {
        vm.expectRevert(ICustody.Aera__GuardianIsZeroAddress.selector);
        new AeraVaultV2(
            address(assetRegistry),
            address(balancerExecution),
            address(0),
            _MAX_GUARDIAN_FEE,
            yieldActionThreshold
        );
    }

    function test_aeraVaultV2Deployment_fail_whenGuardianIsOwner() public {
        vm.expectRevert(ICustody.Aera__GuardianIsOwner.selector);
        new AeraVaultV2(
            address(assetRegistry),
            address(balancerExecution),
            address(this),
            _MAX_GUARDIAN_FEE,
            yieldActionThreshold
        );
    }

    function test_aeraVaultV2Deployment_fail_whenGuardianFeeIsAboveMax()
        public
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__GuardianFeeIsAboveMax.selector,
                _MAX_GUARDIAN_FEE + 1,
                _MAX_GUARDIAN_FEE
            )
        );
        new AeraVaultV2(
            address(assetRegistry),
            address(balancerExecution),
            _GUARDIAN,
            _MAX_GUARDIAN_FEE + 1,
            yieldActionThreshold
        );
    }

    function test_aeraVaultV2Deployment_success() public {
        vm.expectEmit(true, true, true, true);
        emit SetAssetRegistry(address(assetRegistry));
        vm.expectEmit(true, true, true, true);
        emit SetExecution(address(balancerExecution));
        vm.expectEmit(true, true, true, true);
        emit SetGuardian(_GUARDIAN);

        vault = new AeraVaultV2(
            address(assetRegistry),
            address(balancerExecution),
            _GUARDIAN,
            _MAX_GUARDIAN_FEE,
            yieldActionThreshold
        );

        assertEq(address(vault.assetRegistry()), address(assetRegistry));
        assertEq(address(vault.execution()), address(balancerExecution));
        assertEq(vault.guardian(), _GUARDIAN);
        assertEq(vault.guardianFee(), _MAX_GUARDIAN_FEE);
    }
}
