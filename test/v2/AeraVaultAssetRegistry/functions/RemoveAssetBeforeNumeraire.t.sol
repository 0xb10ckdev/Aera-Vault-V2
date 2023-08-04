// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./RemoveAsset.t.sol";

contract RemoveAssetBeforeNumeraireTest is RemoveAssetTest {
    constructor() {
        // found by trial and error to make sure sorted numeraire address
        // is after non-numeraire address
        numeraireSetIdx = 3;
    }
}
