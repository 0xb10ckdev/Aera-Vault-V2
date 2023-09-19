// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;
import "@openzeppelin/IERC20Metadata.sol";
import "./SafeCast.sol";
import "@chainlink/interfaces/AggregatorV2V3Interface.sol";
import {ONE} from "src/v2/Constants.sol";
import "./ICurveFiPool.sol";

/// @title CurveOracleWrapper 
/// @notice Used to calculate price of tokens in a Curve V2 pool
contract CurveOracleWrapper is AggregatorV2V3Interface {
    /// @notice The address of underlying curve pool
    address public immutable pool;

    /// @notice The index in the curve pool of the numeraire asset to price against
    uint256 public immutable numeraireIndex;

    /// @notice 10 ** decimals of numeraire asset
    /// @notice The index in the curve pool of the asset we want a price for
    uint256 public immutable tokenToPriceIndex;

    /// @notice Decimals of price returned by this oracle
    uint8 public immutable decimals;

    /// ERRORS ///

    error TokenToPriceNotFoundInPoool(address pool, address tokenToPrice);
    error NumeraireTokenNotFoundInPool(address pool, address numeraireToken);
    error NotImplemented();

    /// FUNCTIONS ///

    /// @notice Initialize the oracle contract.
    /// @param pool_ The address of the underlying curve pool
    /// @param tokenToPrice The address of the underlying token to get a price for
    /// @param numeraireToken The address of the other token in the pool to price against
    constructor(address pool_, address tokenToPrice, address numeraireToken) {
        // Effects: find numeraire and token to price.
        for (uint256 i = 0; i < 2; i++) {
            address coin = ICurveFiPool(pool_).coins(i);
            if (coin == numeraireToken) {
                numeraireIndex = i;
            } else if (coin == tokenToPrice) {
                tokenToPriceIndex = i;
            }
        }

        // Requirements: check that token to price is part of pool.
        if (tokenToPriceIndex >= 2) {
            revert TokenToPriceNotFoundInPoool(pool_, tokenToPrice);
        }

        // Requirements: check that numeraire is part of pool.
        if (numeraireIndex >= 2) {
            revert NumeraireTokenNotFoundInPool(pool_, numeraireToken);
        }
        
        // Effects: initialize contract variables.
        pool = pool_;
        decimals = 18;
    }
    
    /// @inheritdoc AggregatorV3Interface
    function latestRoundData() external view override returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
        uint256 uintAnswer = ICurveFiPool(pool).price_oracle();
        if (numeraireIndex == 0) {
            uintAnswer = _getReciprocalPrice(uintAnswer);
        }
        answer = SafeCast.toInt256(uintAnswer);

        updatedAt = block.timestamp;

        roundId = 0;
        startedAt = 0;
        answeredInRound = 0;
    }
    
    function _getReciprocalPrice(uint256 price) internal pure returns (uint256) {
        return ONE * ONE / price;
    }
    
    /// @inheritdoc AggregatorV3Interface
    function description() external pure returns (string memory) {
        return "";
    }

    function getAnswer(uint256) external pure returns (int256) {
        revert NotImplemented();
    }

    /// @inheritdoc AggregatorV3Interface
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

    /// @inheritdoc AggregatorV3Interface
    function version() external pure returns (uint256){
        revert NotImplemented();
    }
}