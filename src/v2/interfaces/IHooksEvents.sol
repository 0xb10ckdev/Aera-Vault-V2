// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {TargetSighash} from "../Types.sol";

/// @title Interface for hooks module.
interface IHooksEvents {
    event AddTargetSighash(TargetSighash targetSighash);

    event RemoveTargetSighash(TargetSighash targetSighash);
}
