// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "../dependencies/openzeppelin/IERC20.sol";

interface IBVault {
    enum JoinKind {
        INIT,
        EXACT_TOKENS_IN_FOR_BPT_OUT,
        TOKEN_IN_FOR_EXACT_BPT_OUT,
        ALL_TOKENS_IN_FOR_EXACT_BPT_OUT
    }

    enum PoolBalanceOpKind {
        WITHDRAW,
        DEPOSIT,
        UPDATE
    }

    struct JoinPoolRequest {
        IERC20[] assets;
        uint256[] maxAmountsIn;
        bytes userData;
        bool fromInternalBalance;
    }

    struct ExitPoolRequest {
        IERC20[] assets;
        uint256[] minAmountsOut;
        bytes userData;
        bool toInternalBalance;
    }

    struct PoolBalanceOp {
        PoolBalanceOpKind kind;
        bytes32 poolId;
        IERC20 token;
        uint256 amount;
    }

    function getPoolTokens(bytes32 poolId)
        external
        view
        returns (
            IERC20[] memory tokens,
            uint256[] memory balances,
            uint256 lastChangeBlock
        );

    function joinPool(
        bytes32 poolId,
        address sender,
        address recipient,
        JoinPoolRequest memory request
    ) external payable;

    function exitPool(
        bytes32 poolId,
        address sender,
        address payable recipient,
        ExitPoolRequest memory request
    ) external;

    function managePoolBalance(PoolBalanceOp[] memory ops) external;
}
