// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAeraVaultHooks.sol";

contract DeploymentTest is TestBaseAeraVaultHooks {
    function test_aeraVaultHooksDeployment_fail_whenCustodyIsZeroAddress()
        public
    {
        vm.expectRevert(IHooks.Aera__CustodyIsZeroAddress.selector);
        new AeraVaultHooks(
            address(0),
            _MAX_DAILY_EXECUTION_LOSS,
            new TargetSighash[](0)
        );
    }

    function test_aeraVaultHooksDeployment_fail_whenCustodyIsNotValid()
        public
    {
        vm.expectRevert(
            abi.encodeWithSelector(
                IHooks.Aera__CustodyIsNotValid.selector, address(1)
            )
        );

        new AeraVaultHooks(
            address(1),
            _MAX_DAILY_EXECUTION_LOSS,
            new TargetSighash[](0)
        );
    }

    function test_aeraVaultHooksDeployment_success() public {
        uint256 numERC20 = erc20Assets.length;

        TargetSighash[] memory targetSighashAllowlist =
            new TargetSighash[](numERC20);

        for (uint256 i = 0; i < numERC20; i++) {
            targetSighashAllowlist[i] = TargetSighashLib.toTargetSighash(
                address(erc20Assets[i]), _TRANSFER_SELECTOR
            );
        }

        hooks = new AeraVaultHooks(
            address(vault),
            _MAX_DAILY_EXECUTION_LOSS,
            targetSighashAllowlist
        );

        assertEq(address(hooks.custody()), address(vault));
        assertEq(hooks.maxDailyExecutionLoss(), _MAX_DAILY_EXECUTION_LOSS);
        assertEq(hooks.currentDay(), block.timestamp / 1 days);
        assertEq(hooks.cumulativeDailyMultiplier(), _ONE);

        for (uint256 i = 0; i < numERC20; i++) {
            assertTrue(hooks.targetSighashAllowlist(targetSighashAllowlist[i]));
        }
    }
}
