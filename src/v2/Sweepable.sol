// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/Ownable2Step.sol";
import "@openzeppelin/SafeERC20.sol";
import "./interfaces/ISweepable.sol";

/// @title Sweepable.
/// @notice Aera Sweepable contract.
contract Sweepable is ISweepable, Ownable2Step {
    using SafeERC20 for IERC20;

    /// @inheritdoc ISweepable
    function sweep(address token) external onlyOwner {
        uint256 amount;

        if (token == address(0)) {
            amount = address(this).balance;
            owner().call{value: amount}("");
        } else {
            amount = IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransfer(owner(), amount);
        }

        emit Sweep(token, amount);
    }
}
