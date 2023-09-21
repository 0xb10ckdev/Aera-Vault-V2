// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/IERC20Metadata.sol";
import "./dependencies/openzeppelin/SafeCast.sol";
import "./interfaces/IAeraV2Oracle.sol";
import "./interfaces/IWstETH.sol";
import {ONE} from "src/v2/Constants.sol";

/// ERRORS ///

error AeraPeriphery__WstETHIsZeroAddress();
error AeraPeriphery__InvalidWstETH();

/// @title WstETHOracle
/// @notice Used to calculate price of wstETH.
contract WstETHOracle is IAeraV2Oracle {
    /// @notice The address of wstETH.
    IWstETH public immutable wstETH;

    /// @notice Decimals of price returned by this oracle.
    uint8 public immutable decimals;

    /// FUNCTIONS ///

    /// @notice Initialize the oracle contract.
    /// @param wstETH_ wstETH address.
    constructor(address wstETH_) {
        // Requirements: check wstETH integrity.
        if (wstETH_ == address(0)) {
            revert AeraPeriphery__WstETHIsZeroAddress();
        }
        if (wstETH_.code.length == 0) {
            revert AeraPeriphery__InvalidWstETH();
        }
        try IWstETH(wstETH_).getStETHByWstETH(ONE) returns (uint256) {}
        catch {
            revert AeraPeriphery__InvalidWstETH();
        }

        // Effects: initialize contract variables.
        wstETH = IWstETH(wstETH_);
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
        // In future, we can use the stETH/ETH Chainlink oracle to be slightly more accurate.
        uint256 price = wstETH.getStETHByWstETH(ONE);

        roundId = 0;
        answer = SafeCast.toInt256(price);
        startedAt = 0;
        updatedAt = block.timestamp;
        answeredInRound = 0;
    }
}
