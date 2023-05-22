// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultV2Factory.sol";

contract CreateTest is TestBaseAeraVaultV2Factory {
    uint256 minThreshold;
    uint256 minYieldActionThreshold;

    error Aera__MinThresholdIsZero();
    error Aera__MinYieldActionThresholdIsZero();

    function setUp() public override {
        super.setUp();

        minThreshold = _getScaler(assets[numeraire]);
        minYieldActionThreshold = _getScaler(assets[numeraire]);
    }

    function test_createAeraVaultV2_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        factory.create(
            address(0),
            address(balancerExecution),
            _GUARDIAN,
            _MAX_GUARDIAN_FEE,
            minThreshold,
            minYieldActionThreshold
        );
    }

    function test_createAeraVaultV2_fail_whenAssetRegistryIsZeroAddress()
        public
    {
        vm.expectRevert(ICustody.Aera__AssetRegistryIsZeroAddress.selector);

        factory.create(
            address(0),
            address(balancerExecution),
            _GUARDIAN,
            _MAX_GUARDIAN_FEE,
            minThreshold,
            minYieldActionThreshold
        );
    }

    function test_createAeraVaultV2_fail_whenAssetRegistryIsNotValid() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__AssetRegistryIsNotValid.selector,
                address(1)
            )
        );

        factory.create(
            address(1),
            address(balancerExecution),
            _GUARDIAN,
            _MAX_GUARDIAN_FEE,
            minThreshold,
            minYieldActionThreshold
        );
    }

    function test_createAeraVaultV2_fail_whenExecutionIsZeroAddress() public {
        vm.expectRevert(ICustody.Aera__ExecutionIsZeroAddress.selector);
        factory.create(
            address(assetRegistry),
            address(0),
            _GUARDIAN,
            _MAX_GUARDIAN_FEE,
            minThreshold,
            minYieldActionThreshold
        );
    }

    function test_createAeraVaultV2_fail_whenExecutionIsNotValid() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__ExecutionIsNotValid.selector,
                address(1)
            )
        );

        factory.create(
            address(assetRegistry),
            address(1),
            _GUARDIAN,
            _MAX_GUARDIAN_FEE,
            minThreshold,
            minYieldActionThreshold
        );
    }

    function test_createAeraVaultV2_fail_whenGuardianIsZeroAddress() public {
        vm.expectRevert(ICustody.Aera__GuardianIsZeroAddress.selector);
        factory.create(
            address(assetRegistry),
            address(balancerExecution),
            address(0),
            _MAX_GUARDIAN_FEE,
            minThreshold,
            minYieldActionThreshold
        );
    }

    function test_createAeraVaultV2_fail_whenGuardianIsFactory() public {
        vm.expectRevert(ICustody.Aera__GuardianIsOwner.selector);
        factory.create(
            address(assetRegistry),
            address(balancerExecution),
            address(factory),
            _MAX_GUARDIAN_FEE,
            minThreshold,
            minYieldActionThreshold
        );
    }

    function test_createAeraVaultV2_fail_whenGuardianFeeIsAboveMax() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__GuardianFeeIsAboveMax.selector,
                _MAX_GUARDIAN_FEE + 1,
                _MAX_GUARDIAN_FEE
            )
        );
        factory.create(
            address(assetRegistry),
            address(balancerExecution),
            _GUARDIAN,
            _MAX_GUARDIAN_FEE + 1,
            minThreshold,
            minYieldActionThreshold
        );
    }

    function test_createAeraVaultV2_fail_whenMinThresholdIsZero() public {
        vm.expectRevert(Aera__MinThresholdIsZero.selector);
        factory.create(
            address(assetRegistry),
            address(balancerExecution),
            _GUARDIAN,
            _MAX_GUARDIAN_FEE,
            0,
            minYieldActionThreshold
        );
    }

    function test_createAeraVaultV2_fail_whenMinYieldActionThresholdIsZero()
        public
    {
        vm.expectRevert(Aera__MinYieldActionThresholdIsZero.selector);
        factory.create(
            address(assetRegistry),
            address(balancerExecution),
            _GUARDIAN,
            _MAX_GUARDIAN_FEE,
            minThreshold,
            0
        );
    }

    function test_createAeraVaultV2_success() public {
        vm.expectEmit(true, true, true, true);
        emit SetAssetRegistry(address(assetRegistry));
        vm.expectEmit(true, true, true, true);
        emit SetExecution(address(balancerExecution));
        vm.expectEmit(true, true, true, true);
        emit SetGuardian(_GUARDIAN);

        factory.create(
            address(assetRegistry),
            address(balancerExecution),
            _GUARDIAN,
            _MAX_GUARDIAN_FEE,
            minThreshold,
            minYieldActionThreshold
        );
    }
}
