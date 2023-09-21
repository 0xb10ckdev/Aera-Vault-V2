// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

/// @title IAeraV2Oracle
/// @notice Used to calculate price of tokens using the same API as Chainlink
interface IAeraV2Oracle {
    /// @notice The decimals returned from the answer in latestRoundData
    function decimals() external view returns (uint8);

    /// @notice Returns the latest price.
    ///         roundID, startedAt, answeredInRound are optional and Chainlink-specific
    ///         updatedAt is the most recent timestamp the price was updated
    ///         answer is the price
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}
