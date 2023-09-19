// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/Ownable.sol";

contract FixedPriceOracle is Ownable {
    int256 public price;
    uint8 public decimals;

    constructor(int256 _price, address _owner, uint8 decimals_) Ownable() {
        price = _price;
        _transferOwnership(_owner);
        decimals = decimals_;
    }

    function setPrice(int256 _price) onlyOwner public {
        price = _price;
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
        return (0, price, block.timestamp, block.timestamp, 0);
    }
}