// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/IERC20Metadata.sol";
import "./SafeCast.sol";
import {ONE} from "src/v2/Constants.sol";
import "./ICurveFiPool.sol";

/// @title CurveOracle
/// @notice Used to calculate price of tokens in a Curve V2 pool
contract CurveOracle {
    /// @notice The address of underlying curve pool
    address public immutable pool;

    /// @notice Decimals of price returned by this oracle (matches the quote token's decimals)
    uint8 public immutable decimals;

    /// @notice "BASE/QUOTE" 
    string public description;

    /// @notice Whether the price returned by this oracle inverts the pool's pricing oracle
    bool private immutable invertedPrice;

    /// @notice If invertedPrice, then invertedNumerator / price is what's returned
    uint256 private immutable invertedNumerator;

    /// ERRORS ///

    error CannotPrice(
        address pool,
        address poolCoin0,
        address poolCoin1,
        address baseToken,
        address quoteToken
    );

    /// FUNCTIONS ///

    /// @notice Initialize the oracle contract.
    /// @param pool_ The address of the underlying curve pool
    /// @param baseToken The address of the underlying token to get a price for
    /// @param quoteToken The address of the other token in the pool to price against
    constructor(address pool_, address baseToken, address quoteToken) {
        ICurveFiPool c = ICurveFiPool(pool_);
        address coin0 = c.coins(0);
        address coin1 = c.coins(1);

        // Curve's coin(0) is the quote token
        if (baseToken == coin1 && quoteToken == coin0) {
            invertedPrice = false;
        } else if (baseToken == coin0 && quoteToken == coin1) {
            invertedPrice = true;
        } else {
            revert CannotPrice(pool_, coin0, coin1, baseToken, quoteToken);
        }

        uint8 baseDecimals = IERC20Metadata(baseToken).decimals();
        uint8 quoteDecimals = IERC20Metadata(quoteToken).decimals();

        pool = pool_;
        description = string.concat(
            IERC20Metadata(baseToken).symbol(),
            "/",
            IERC20Metadata(quoteToken).symbol()
        );

        decimals = quoteDecimals; 
        invertedNumerator = 10 ** (baseDecimals + quoteDecimals);
    }

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        )
    {
        uint256 price = ICurveFiPool(pool).price_oracle();
        if (invertedPrice) {
            price = invertedNumerator / price;
        }

        roundId = 0;
        answer = SafeCast.toInt256(price);
        startedAt = 0;
        updatedAt = block.timestamp;
        answeredInRound = 0;
    }
}
