// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/IERC4626.sol";

contract TestBaseVariables {
    IERC20[] public assets;
    IERC20[] public erc20Assets;
    IERC4626[] public yieldAssets;
}
