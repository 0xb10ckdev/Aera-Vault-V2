// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;
import "@openzeppelin/IERC20Metadata.sol";
import "./ICurveFiPool.sol";
import "./IAeraV2Oracle.sol";

contract CurveOracleWrapper is IAeraV2Oracle {
    address public pool;
    uint256 public numeraireIndex;
    uint256 public numeraireDecimals;
    uint256 public tokenToPriceIndex;
    uint256 public decimals_;
    constructor(address pool_, address tokenToPrice, address numeraireToken) {
        pool = pool_;
        for (uint256 i = 0; i < 2; i++) {
            if (ICurveFiPool(pool).coins(i) == numeraireToken) {
                numeraireIndex = i;
            } else if (ICurveFiPool(pool).coins(i) == tokenToPrice) {
                tokenToPriceIndex = i;
            }
        }
        if (tokenToPriceIndex >= 2) {
            revert("tokenToPrice not found in pool");
        }
        if (numeraireIndex >= 2) {
            revert("numeraireToken not found in pool");
        }
        numeraireDecimals = IERC20Metadata(numeraireToken).decimals();
        decimals_ = IERC20Metadata(tokenToPrice).decimals();
    }
    
    function decimals() external view override returns (uint256) {
        return decimals_;
    }

    function latestRoundData() external view override returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound) {
        uint256 uintAnswer = ICurveFiPool(pool).get_dy(tokenToPriceIndex, numeraireIndex, 10**numeraireDecimals);
        if (uintAnswer > 2**255) {
            revert("overflow");
        }
        answer = int256(uintAnswer);

        updatedAt = block.timestamp;
    }
}