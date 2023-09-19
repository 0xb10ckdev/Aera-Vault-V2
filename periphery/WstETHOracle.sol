// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;
import "@openzeppelin/IERC20Metadata.sol";
import "@chainlink/interfaces/AggregatorV2V3Interface.sol";
import "./IWstETH.sol";
import {ONE} from "src/v2/Constants.sol";

/// @title WstETHOracle
/// @notice Used to calculate price of wstETH.
contract WstETHOracle is AggregatorV2V3Interface {
    /// @notice The address of wstETH.
    address public immutable wstETH;

    /// @notice Decimals of price returned by this oracle.
    uint8 public immutable decimals;

    /// ERRORS ///

    error PriceOverflowsInt256();
    error NotImplemented();

    /// FUNCTIONS ///

    /// @notice Initialize the oracle contract.
    /// @param wstETH_ wstETH address.
    constructor(address wstETH_) {
        // Effects: initialize contract variables.
        wstETH = wstETH_;
        decimals = 18;
    }
    
    /// @inheritdoc AggregatorV3Interface
    function latestRoundData() external view override returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
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
    
    /// @inheritdoc AggregatorV3Interface
    function description() external pure returns (string memory) {
        return "";
    }

    function getAnswer(uint256) external pure returns (int256) {
        revert NotImplemented();
    }

    function getRoundData(uint80) 
        external pure 
        returns (
          uint80,
          int256,
          uint256,
          uint256,
          uint80
        ) {
        revert NotImplemented();
    }

    function getTimestamp(uint256) external pure returns (uint256) {
        revert NotImplemented();
    }

    function latestAnswer() external pure returns (int256) {
        revert NotImplemented();
    }

    function latestRound() external pure returns (uint256) {
        revert NotImplemented();
    }

    function latestTimestamp() external pure returns (uint256) {
        revert NotImplemented();
    }

    function version() external pure returns (uint256){
        revert NotImplemented();
    }
}