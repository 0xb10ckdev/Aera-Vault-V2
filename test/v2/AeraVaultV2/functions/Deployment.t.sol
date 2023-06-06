// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2.sol";

contract DeploymentTest is TestBaseAeraVaultV2 {
    uint256 minThreshold;
    uint256 minYieldActionThreshold;

    error Aera__MinThresholdIsZero();
    error Aera__MinYieldActionThresholdIsZero();

    function setUp() public override {
        super.setUp();

        minThreshold = _getScaler(assets[numeraire]);
        minYieldActionThreshold = _getScaler(assets[numeraire]);
    }

    function test_aeraVaultV2Deployment_fail_whenAssetRegistryIsZeroAddress()
        public
    {
        vm.expectRevert(ICustody.Aera__AssetRegistryIsZeroAddress.selector);
        new AeraVaultV2(
            address(0),
            address(balancerExecution),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_GUARDIAN_FEE,
            minThreshold,
            minYieldActionThreshold
        );
    }

    function test_aeraVaultV2Deployment_fail_whenAssetRegistryIsNotValid()
        public
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__AssetRegistryIsNotValid.selector,
                address(1)
            )
        );

        new AeraVaultV2(
            address(1),
            address(balancerExecution),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_GUARDIAN_FEE,
            minThreshold,
            minYieldActionThreshold
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
            _FEE_RECIPIENT,
            _MAX_GUARDIAN_FEE,
            minThreshold,
            minYieldActionThreshold
        );
    }

    function test_aeraVaultV2Deployment_fail_whenExecutionIsNotValid() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__ExecutionIsNotValid.selector,
                address(1)
            )
        );

        new AeraVaultV2(
            address(assetRegistry),
            address(1),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_GUARDIAN_FEE,
            minThreshold,
            minYieldActionThreshold
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
            _FEE_RECIPIENT,
            _MAX_GUARDIAN_FEE,
            minThreshold,
            minYieldActionThreshold
        );
    }

    function test_aeraVaultV2Deployment_fail_whenGuardianIsOwner() public {
        vm.expectRevert(ICustody.Aera__GuardianIsOwner.selector);
        new AeraVaultV2(
            address(assetRegistry),
            address(balancerExecution),
            address(this),
            _FEE_RECIPIENT,
            _MAX_GUARDIAN_FEE,
            minThreshold,
            minYieldActionThreshold
        );
    }

    function test_aeraVaultV2Deployment_fail_whenFeeRecipientIsZeroAddress()
        public
    {
        vm.expectRevert(ICustody.Aera__FeeRecipientIsZeroAddress.selector);
        new AeraVaultV2(
            address(assetRegistry),
            address(balancerExecution),
            _GUARDIAN,
            address(0),
            _MAX_GUARDIAN_FEE,
            minThreshold,
            minYieldActionThreshold
        );
    }

    function test_aeraVaultV2Deployment_fail_whenFeeRecipientIsOwner() public {
        vm.expectRevert(ICustody.Aera__FeeRecipientIsOwner.selector);
        new AeraVaultV2(
            address(assetRegistry),
            address(balancerExecution),
            _GUARDIAN,
            address(this),
            _MAX_GUARDIAN_FEE,
            minThreshold,
            minYieldActionThreshold
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
            _FEE_RECIPIENT,
            _MAX_GUARDIAN_FEE + 1,
            minThreshold,
            minYieldActionThreshold
        );
    }

    function test_aeraVaultV2Deployment_fail_whenMinThresholdIsZero() public {
        vm.expectRevert(Aera__MinThresholdIsZero.selector);
        new AeraVaultV2(
            address(assetRegistry),
            address(balancerExecution),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_GUARDIAN_FEE,
            0,
            minYieldActionThreshold
        );
    }

    function test_aeraVaultV2Deployment_fail_whenMinYieldActionThresholdIsZero()
        public
    {
        vm.expectRevert(Aera__MinYieldActionThresholdIsZero.selector);
        new AeraVaultV2(
            address(assetRegistry),
            address(balancerExecution),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_GUARDIAN_FEE,
            minThreshold,
            0
        );
    }

    function test_aeraVaultV2Deployment_success() public {
        vm.expectEmit(true, true, true, true);
        emit SetAssetRegistry(address(assetRegistry));
        vm.expectEmit(true, true, true, true);
        emit SetExecution(address(balancerExecution));
        vm.expectEmit(true, true, true, true);
        emit SetGuardian(_GUARDIAN, _FEE_RECIPIENT);

        vault = new AeraVaultV2(
            address(assetRegistry),
            address(balancerExecution),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_GUARDIAN_FEE,
            minThreshold,
            minYieldActionThreshold
        );

        assertEq(address(vault.assetRegistry()), address(assetRegistry));
        assertEq(address(vault.execution()), address(balancerExecution));
        assertEq(vault.guardian(), _GUARDIAN);
        assertEq(vault.feeRecipient(), _FEE_RECIPIENT);
        assertEq(vault.guardianFee(), _MAX_GUARDIAN_FEE);
    }
}
