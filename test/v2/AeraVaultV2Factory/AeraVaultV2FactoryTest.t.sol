// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "src/v2/interfaces/ICustodyEvents.sol";
import "src/v2/AeraVaultV2Factory.sol";
import {TestBaseCustody} from "test/v2/utils/TestBase/TestBaseCustody.sol";

contract AeraVaultV2FactoryTest is TestBaseCustody, ICustodyEvents {
    AeraVaultV2Factory factory;

    function setUp() public virtual override {
        super.setUp();

        factory = new AeraVaultV2Factory();
    }

    function test_createAeraVaultV2_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        factory.create(address(0), _GUARDIAN, _FEE_RECIPIENT, _MAX_FEE);
    }

    function test_createAeraVaultV2_fail_whenAssetRegistryIsZeroAddress()
        public
    {
        vm.expectRevert(ICustody.Aera__AssetRegistryIsZeroAddress.selector);

        factory.create(address(0), _GUARDIAN, _FEE_RECIPIENT, _MAX_FEE);
    }

    function test_createAeraVaultV2_fail_whenAssetRegistryIsNotValid()
        public
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__AssetRegistryIsNotValid.selector, address(1)
            )
        );

        factory.create(address(1), _GUARDIAN, _FEE_RECIPIENT, _MAX_FEE);
    }

    function test_createAeraVaultV2_fail_whenGuardianIsZeroAddress() public {
        vm.expectRevert(ICustody.Aera__GuardianIsZeroAddress.selector);
        factory.create(
            address(assetRegistry), address(0), _FEE_RECIPIENT, _MAX_FEE
        );
    }

    function test_createAeraVaultV2_fail_whenGuardianIsFactory() public {
        vm.expectRevert(ICustody.Aera__GuardianIsOwner.selector);
        factory.create(
            address(assetRegistry), address(factory), _FEE_RECIPIENT, _MAX_FEE
        );
    }

    function test_createAeraVaultV2_fail_whenFeeRecipientIsZeroAddress()
        public
    {
        vm.expectRevert(ICustody.Aera__FeeRecipientIsZeroAddress.selector);
        factory.create(address(assetRegistry), _GUARDIAN, address(0), _MAX_FEE);
    }

    function test_createAeraVaultV2_fail_whenFeeRecipientIsFactory() public {
        vm.expectRevert(ICustody.Aera__FeeRecipientIsOwner.selector);
        factory.create(
            address(assetRegistry), _GUARDIAN, address(factory), _MAX_FEE
        );
    }

    function test_createAeraVaultV2_fail_whenFeeIsAboveMax() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ICustody.Aera__FeeIsAboveMax.selector, _MAX_FEE + 1, _MAX_FEE
            )
        );
        factory.create(
            address(assetRegistry), _GUARDIAN, _FEE_RECIPIENT, _MAX_FEE + 1
        );
    }

    function test_createAeraVaultV2_success() public {
        vm.expectEmit(true, true, true, true);
        emit SetAssetRegistry(address(assetRegistry));
        vm.expectEmit(true, true, true, true);
        emit SetGuardianAndFeeRecipient(_GUARDIAN, _FEE_RECIPIENT);

        factory.create(
            address(assetRegistry), _GUARDIAN, _FEE_RECIPIENT, _MAX_FEE
        );
    }
}
