// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

interface IAsset {}

enum SwapKind {
    GIVEN_IN,
    GIVEN_OUT
}

struct SingleSwap {
    bytes32 poolId;
    SwapKind kind;
    IAsset assetIn;
    IAsset assetOut;
    uint256 amount;
    bytes userData;
}

struct FundManagement {
    address sender;
    bool fromInternalBalance;
    address payable recipient;
    bool toInternalBalance;
}

interface Balancer {
    function swap(
        SingleSwap memory request,
        FundManagement memory funds,
        uint256 limit,
        uint256 deadline
    ) external returns (uint256 assetDelta);
}
