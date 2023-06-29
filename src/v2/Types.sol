// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/IERC20.sol";

type TargetSighash is uint256;

/// @param asset Address of asset.
/// @param value Value of asset.
struct AssetValue {
    IERC20 asset;
    uint256 value;
}

/// @param target Address of target.
/// @param value Amount of native token.
/// @param data Calldata of operation.
struct Operation {
    address target;
    uint256 value;
    bytes data;
}
