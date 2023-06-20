// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseConstraints.sol";
import "src/v2/AeraVaultV2.sol";

contract SetCustodyTest is TestBaseConstraints {
    AeraVaultV2 newCustody;

    function setUp() public override {
        super.setUp();

        newCustody = new AeraVaultV2(
            address(assetRegistry),
            address(balancerExecution),
            address(constraints),
            _GUARDIAN,
            _FEE_RECIPIENT,
            _MAX_GUARDIAN_FEE,
            _getScaler(assets[numeraire]),
            _getScaler(assets[numeraire])
        );
    }

    function test_setCustody_fail_whenCallerIsNotOwner() public {
        vm.expectRevert(bytes("Ownable: caller is not the owner"));

        vm.prank(_USER);
        constraints.setCustody(address(newCustody));
    }

    function test_setCustody_fail_whenCustodyIsZeroAddress() public {
        vm.expectRevert(IConstraints.Aera__CustodyIsZeroAddress.selector);

        constraints.setCustody(address(0));
    }

    function test_setCustody_fail_whenCustodyIsNotValid() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                IConstraints.Aera__CustodyIsNotValid.selector, address(1)
            )
        );

        constraints.setCustody(address(1));
    }

    function test_setCustody_success() public virtual {
        vm.expectEmit(true, true, true, true, address(constraints));
        emit SetCustody(address(newCustody));

        constraints.setCustody(address(newCustody));

        assertEq(address(constraints.custody()), address(newCustody));
    }
}
