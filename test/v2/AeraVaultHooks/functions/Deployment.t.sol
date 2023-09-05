// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAeraVaultHooks.sol";

contract DeploymentTest is TestBaseAeraVaultHooks {
    function test_aeraVaultHooksDeployment_fail_whenVaultIsZeroAddress()
        public
    {
        vm.expectRevert(AeraVaultHooks.Aera__VaultIsZeroAddress.selector);
        new AeraVaultHooks(
            address(this),
            address(0),
            _MAX_DAILY_EXECUTION_LOSS,
            new TargetSighashData[](0)
        );
    }

    function test_aeraVaultHooksDeployment_fail_whenOwnerIsZeroAddress()
        public
    {
        vm.expectRevert(
            AeraVaultHooks.Aera__HooksInitialOwnerIsZeroAddress.selector
        );
        new AeraVaultHooks(
            address(0),
            address(1),
            _MAX_DAILY_EXECUTION_LOSS,
            new TargetSighashData[](0)
        );
    }

    function test_aeraVaultHooksDeployment_fail_whenMaxDailyExecutionLossIsGreaterThanOne(
    ) public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultHooks
                    .Aera__MaxDailyExecutionLossIsGreaterThanOne
                    .selector
            )
        );

        new AeraVaultHooks(
            address(this),
            address(vault),
            1.1e18,
            new TargetSighashData[](0)
        );
    }

    function test_aeraVaultHooksDeployment_success() public {
        uint256 numERC20 = erc20Assets.length;

        TargetSighashData[] memory targetSighashAllowlist =
            new TargetSighashData[](numERC20);

        for (uint256 i = 0; i < numERC20; i++) {
            targetSighashAllowlist[i] = TargetSighashData({
                target: address(erc20Assets[i]),
                selector: IERC20.transfer.selector
            });
        }

        hooks = new AeraVaultHooks(
            address(this),
            address(vault),
            _MAX_DAILY_EXECUTION_LOSS,
            targetSighashAllowlist
        );

        assertEq(address(hooks.vault()), address(vault));
        assertEq(hooks.maxDailyExecutionLoss(), _MAX_DAILY_EXECUTION_LOSS);
        assertEq(hooks.currentDay(), block.timestamp / 1 days);
        assertEq(hooks.cumulativeDailyMultiplier(), _ONE);

        for (uint256 i = 0; i < numERC20; i++) {
            assertTrue(hooks.targetSighashAllowed(targetSighashAllowlist[i]));
        }
    }
}
