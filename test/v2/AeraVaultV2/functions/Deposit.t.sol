// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../../utils/TestBaseCustody/functions/Deposit.sol";
import "../TestBaseAeraVaultV2.sol";

contract DepositTest is BaseDepositTest, TestBaseAeraVaultV2 {
    function setUp() public override {
        super.setUp();

        for (uint256 i = 0; i < erc20Assets.length; i++) {
            depositAmounts.push(
                ICustody.AssetValue(
                    erc20Assets[i],
                    5 * _getScaler(erc20Assets[i])
                )
            );
        }
    }
}
