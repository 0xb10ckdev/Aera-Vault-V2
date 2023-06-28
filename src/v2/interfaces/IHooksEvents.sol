// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/IERC20.sol";

/// @title Interface for hooks module.
interface IHooksEvents {
    type TargetSighash is uint256;

    event AddTargetSighash(TargetSighash targetSighash);

    event RemoveTargetSighash(TargetSighash targetSighash);
}
