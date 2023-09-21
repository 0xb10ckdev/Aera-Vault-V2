// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {Operation} from "src/v2/Types.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/IERC4626.sol";
import "@openzeppelin/IERC20.sol";
import "periphery/interfaces/ICurveFiPool.sol";


library Ops {
    struct Asset {
        address asset;
        bool isERC4626;
        address oracle;
    }

    function approve(
        address token,
        address spender,
        uint256 amount
    ) public pure returns (Operation memory) {
        return Operation({
            data: abi.encodePacked(
                IERC20.approve.selector, abi.encode(spender, amount)
                ),
            target: token,
            value: 0
        });
    }

    function swapExactInput(
        address swapRouter,
        ISwapRouter.ExactInputParams memory params
    ) public pure returns (Operation memory) {
        return Operation({
            data: abi.encodePacked(
                ISwapRouter.exactInput.selector, abi.encode(params)
                ),
            target: swapRouter,
            value: 0
        });
    }

    function swapExactOutput(
        address swapRouter,
        ISwapRouter.ExactOutputParams memory params
    ) public pure returns (Operation memory) {
        return Operation({
            data: abi.encodePacked(
                ISwapRouter.exactOutput.selector, abi.encode(params)
                ),
            target: swapRouter,
            value: 0
        });
    }

    function deposit(
        address token,
        uint256 amount,
        address recipient
    ) public pure returns (Operation memory) {
        return Operation({
            data: abi.encodePacked(
                IERC4626.deposit.selector, abi.encode(amount, recipient)
                ),
            target: token,
            value: 0
        });
    }

    function withdraw(
        address token,
        uint256 amount,
        address recipient
    ) public pure returns (Operation memory) {
        return Operation({
            data: abi.encodePacked(
                IERC4626.withdraw.selector, abi.encode(amount, recipient, recipient)
                ),
            target: token,
            value: 0
        });
    }

    function curveSwap(
        address pool,
        address tokenIn,
        address tokenOut,
        uint256 tradeSize,
        uint256 minReceived
    ) public view returns (Operation memory) {
        ICurveFiPool p = ICurveFiPool(pool);
        address coin0 = p.coins(0);
        address coin1 = p.coins(1);
        uint256 indexIn;
        uint256 indexOut;

        if (coin0 == tokenIn && coin1 == tokenOut) {
            indexIn = 0;
            indexOut = 1;
        } else if (coin1 == tokenIn && coin0 == tokenOut) {
            indexIn = 1;
            indexOut = 0;
        } else {
            revert("Invalid token pair");
        }

        return Operation({
            data: abi.encodePacked(
                ICurveFiPool.exchange.selector,
                abi.encode(indexIn, indexOut, tradeSize, minReceived)
                ),
            target: pool,
            value: 0
        });
    }
}