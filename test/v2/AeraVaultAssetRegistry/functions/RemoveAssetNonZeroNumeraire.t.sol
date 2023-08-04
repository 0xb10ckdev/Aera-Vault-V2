// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./RemoveAsset.t.sol";

contract RemoveAssetTestNonZeroNumeraire is RemoveAssetTest {
    constructor() {
        numeraireSetIdx = 3;
    }
}
