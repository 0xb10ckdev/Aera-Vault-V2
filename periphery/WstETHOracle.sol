// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/IERC20Metadata.sol";
import "./IWstETH.sol";
import "./IAeraV2Oracle.sol";
import {ONE} from "src/v2/Constants.sol";

/// @title WstETHOracle
/// @notice Used to calculate price of wstETH.
contract WstETHOracle is IAeraV2Oracle {
    /// @notice The address of wstETH.
    address public immutable wstETH;

    /// @notice Decimals of price returned by this oracle.
    uint8 public immutable decimals;

    /// ERRORS ///

    error PriceOverflowsInt256();

    /// FUNCTIONS ///

    /// @notice Initialize the oracle contract.
    /// @param wstETH_ wstETH address.
    constructor(address wstETH_) {
        // Effects: initialize contract variables.
        wstETH = wstETH_;
        decimals = 18;
    }

    /// @inheritdoc IAeraV2Oracle
    function latestRoundData()
        external
        view
        override
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        // Assumes ETH : stETH exchange rate of 1 : 1.
        // In future, can use stETH/ETH chainlink oracle to be slightly more accurate
        uint256 uintAnswer = IWstETH(wstETH).getStETHByWstETH(ONE);

        if (uintAnswer > uint256(type(int256).max)) {
            revert PriceOverflowsInt256();
        }
        answer = int256(uintAnswer);

        updatedAt = block.timestamp;

        roundId = 0;
        startedAt = 0;
        answeredInRound = 0;
    }
}
