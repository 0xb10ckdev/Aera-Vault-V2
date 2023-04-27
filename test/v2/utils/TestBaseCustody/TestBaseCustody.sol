// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {TestBase} from "../../../utils/TestBase.sol";
import "../../../../src/v2/dependencies/openzeppelin/IERC20.sol";
import "../../../../src/v2/interfaces/ICustody.sol";
import "../../../../src/v2/interfaces/ICustodyEvents.sol";

abstract contract TestBaseCustody is TestBase, ICustodyEvents {
    ICustody custody;
    IERC20[] erc20Assets;
}
