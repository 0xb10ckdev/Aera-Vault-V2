// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;
import "@openzeppelin/IERC20Metadata.sol";
import "./ICurveFiPool.sol";

/// @title CurveOracleWrapper 
/// @notice Used to calculate price of tokens in a Curve V2 pool
contract CurveOracleWrapper is AggregatorV2V3Interface {
    /// @notice The address of underlying curve pool
    address public immutable pool;

    /// @notice The index in the curve pool of the numeraire asset to price against
    uint256 public immutable numeraireIndex;

    /// @notice 10 ** decimals of numeraire asset
    uint256 public immutable numeraireScale;

    /// @notice The index in the curve pool of the asset we want a price for
    uint256 public immutable tokenToPriceIndex;

    /// @notice Decimals of price returned by this oracle
    uint256 public immutable decimals;

    /// ERRORS ///

    error TokenToPriceNotFoundInPoool(address pool, address tokenToPrice);
    error NumeraireTokenNotFoundInPool(address pool, address numeraireToken);
    error CurvePriceOverflowsInt256();

    /// FUNCTIONS ///

    /// @notice Initialize the oracle contract.
    /// @param pool_ The address of the underlying curve pool
    /// @param tokenToPrice_ The address of the underlying token to get a price for
    /// @param numeraireToken The address of the other token in the pool to price against
    constructor(address pool_, address tokenToPrice, address numeraireToken) {
        // Effects: find numeraire and token to price.
        for (uint256 i = 0; i < 2; i++) {
            if (ICurveFiPool(pool).coins(i) == numeraireToken) {
                numeraireIndex = i;
            } else if (ICurveFiPool(pool).coins(i) == tokenToPrice) {
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
        numeraireScale = 10 ** IERC20Metadata(numeraireToken).decimals();
        decimals = IERC20Metadata(tokenToPrice).decimals();
    }
    
    /// @inheritdoc AggregatorV2V3Interface
    function latestRoundData() external view override returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
        uint256 uintAnswer = ICurveFiPool(pool).get_dy(numeraireIndex, tokenToPriceIndex, numeraireScale);
        if (uintAnswer > type(int256).max) {
            revert CurvePriceOverflowsInt256();
        }
        answer = int256(uintAnswer);

        updatedAt = block.timestamp;
    }
}