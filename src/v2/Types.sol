// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/IERC20.sol";

/// @param asset Address of asset.
/// @param value Value of asset.
struct AssetValue {
    IERC20 asset;
    uint256 value;
}

struct Operation {
    address target;
    uint256 value;
    bytes data;
}
