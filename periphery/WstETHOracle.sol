// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;
import "@openzeppelin/IERC20Metadata.sol";
import "@chainlink/interfaces/AggregatorV2V3Interface.sol";
import "./WstETH.sol";

/// @title CurveOracleWrapper 
/// @notice Used to calculate price of tokens in a Curve V2 pool
contract WstETHOracle is AggregatorV2V3Interface {
    /// @notice The address of wstETH
    address public immutable wstETH;

    /// @notice Decimals of price returned by this oracle
    uint8 public immutable decimals;

    uint256 internal constant ONE = 10**18;

    /// ERRORS ///

    error TokenToPriceNotFoundInPoool(address pool, address tokenToPrice);
    error NumeraireTokenNotFoundInPool(address pool, address numeraireToken);
    error PriceOverflowsInt256();
    error NotImplemented();

    /// FUNCTIONS ///

    /// @notice Initialize the oracle contract.
    /// @param pool_ The address of the underlying curve pool
    /// @param tokenToPrice The address of the underlying token to get a price for
    /// @param numeraireToken The address of the other token in the pool to price against
    constructor(address wstETH_) {
        
        // Effects: initialize contract variables.
        wstETH = wstETH_;
        decimals = 18;
    }
    
    /// @inheritdoc AggregatorV3Interface
    function latestRoundData() external view override returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
        uint256 uintAnswer = WstETH(wstEth).getStETHByWstETH(ONE);

        if (uintAnswer > uint256(type(int256).max)) {
            revert PriceOverflowsInt256();
        }
        answer = int256(uintAnswer);

        updatedAt = block.timestamp;
    }
    
    /// @inheritdoc AggregatorV3Interface
    function description() external view returns (string memory) {
        return "";
    }

    function getAnswer(uint256 roundId) external view returns (int256) {
        revert NotImplemented();
    }

    /// @inheritdoc AggregatorV3Interface
    function getRoundData(uint80 _roundId) 
        external view 
        returns (
          uint80 roundId,
          int256 answer,
          uint256 startedAt,
          uint256 updatedAt,
          uint80 answeredInRound
        ) {
        revert NotImplemented();
    }

    function getTimestamp(uint256 roundId) external view returns (uint256) {
        revert NotImplemented();
    }

    function latestAnswer() external view returns (int256) {
        revert NotImplemented();
    }

    function latestRound() external view returns (uint256) {
        revert NotImplemented();
    }

    function latestTimestamp() external view returns (uint256) {
        revert NotImplemented();
    }

    /// @inheritdoc AggregatorV3Interface
    function version() external view returns (uint256){
        revert NotImplemented();
    }
}