// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../../utils/TestBaseCustody/functions/Withdraw.sol";
import "../TestBaseAeraVaultV2.sol";

contract WithdrawTest is BaseWithdrawTest, TestBaseAeraVaultV2 {
    function setUp() public override {
        super.setUp();

        for (uint256 i = 0; i < erc20Assets.length; i++) {
            withdrawAmounts.push(ICustody.AssetValue(erc20Assets[i], _ONE));
        }
    }
}
