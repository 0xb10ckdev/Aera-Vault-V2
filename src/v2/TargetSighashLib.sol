// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {TargetSighash} from "./Types.sol";

/// @title TargetSighashLib
/// @notice Conversion operations for the TargetSighash compound type.
library TargetSighashLib {
    /// @notice Get sighash from target and selector.
    /// @param target Target contract address.
    /// @param selector Function selector.
    /// @return targetSighash Packed value of target and selector.
    /// @dev The packing is done as follows:
    ///      [<empty> 64 bits] [target 160 bits] [selector 32 bits]
    function toTargetSighash(
        address target,
        bytes4 selector
    ) internal pure returns (TargetSighash targetSighash) {
        // Upcast to uint256 is required to prevent truncation during left shift.
        targetSighash = TargetSighash.wrap(
            (uint256(uint160(target)) << 32) | uint32(selector)
        );
    }
}
