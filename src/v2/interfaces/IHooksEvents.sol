// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/IERC20.sol";
import {TargetSighash} from "../Types.sol";

/// @title Interface for hooks module.
interface IHooksEvents {
    event AddTargetSighash(TargetSighash targetSighash);

    event RemoveTargetSighash(TargetSighash targetSighash);
}
