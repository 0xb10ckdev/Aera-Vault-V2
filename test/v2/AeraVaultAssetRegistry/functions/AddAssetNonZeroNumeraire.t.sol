// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./AddAsset.t.sol";

contract AddAssetTestNonZeroNumeraire is AddAssetTest {
    constructor() {
        numeraireSetIdx = 3;
    }
}
