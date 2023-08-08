// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./AddAsset.t.sol";

contract AddAssetAtEnd is AddAssetTest {
    function setUp() public override {
        _deploy();

        // the high number to start (51) is just to make sure we didn't already
        // create this asset previously, and so ensures the address is different
        address lastAssetAddress = address(assets[numAssets - 1].asset);
        // loop until we create a new asset with higher address than all previously
        for (uint256 i = 51; i < 51000; i++) {
            (, newERC20Asset) = _createAsset(false, address(0), i);
            if (address(newERC20Asset.asset) > lastAssetAddress) {
                break;
            }
        }
        address newERC20Address = address(newERC20Asset.asset);
        for (uint256 i = 51; i < 51000; i++) {
            (, newERC4626Asset) = _createAsset(true, nonNumeraireAsset, i);
            if (address(newERC4626Asset.asset) > newERC20Address) {
                break;
            }
        }
    }
}
