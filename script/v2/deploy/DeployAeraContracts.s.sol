// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {DeployAeraContractsBase} from
    "script/v2/deploy/DeployAeraContractsBase.s.sol";
import {DeployScriptBase} from "script/utils/DeployScriptBase.sol";

contract DeployAeraContracts is
    DeployScriptBase(true),
    DeployAeraContractsBase
{}
