// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "src/v2/AeraVaultHooks.sol";
import "src/v2/interfaces/IHooksEvents.sol";
import {TestBaseCustody} from "test/v2/utils/TestBase/TestBaseCustody.sol";

contract TestBaseAeraVaultHooks is TestBaseCustody, IHooksEvents {
    bytes4 internal constant _APPROVE_SELECTOR =
        bytes4(keccak256("approve(address,uint256)"));
    bytes4 internal constant _INCREASE_ALLOWANCE_SELECTOR =
        bytes4(keccak256("increaseAllowance(address,uint256)"));
    bytes4 internal constant _TRANSFER_SELECTOR =
        bytes4(keccak256("transfer(address,uint256)"));
}
