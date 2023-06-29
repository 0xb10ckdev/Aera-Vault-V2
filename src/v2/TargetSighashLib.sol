// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {TargetSighash} from "./Types.sol";

/// @title Library for TargetSighash type.
library TargetSighashLib {
    /// @notice Get sigHash from target and selector.
    /// @param target Address of target.
    /// @param selector Selector of function.
    /// @return sigHash TargetSighash for target and selector.
    function toTargetSighash(
        address target,
        bytes4 selector
    ) internal pure returns (TargetSighash sigHash) {
        sigHash = TargetSighash.wrap(uint160(target) << 32 | uint32(selector));
    }
}
