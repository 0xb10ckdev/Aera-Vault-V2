// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "./AddAsset.t.sol";

contract AddAssetAtEnd is AddAssetTest {
    function setUp() public override {
        _deploy();

        address newERC20Address = address(type(uint160).max - 1);
        address newERC4626Address = address(type(uint160).max);

        (, newERC20Asset) = _createAsset(false, address(0), 51);
        vm.etch(newERC20Address, address(newERC20Asset.asset).code);
        newERC20Asset.asset = IERC20(newERC20Address);

        (, newERC4626Asset) = _createAsset(true, nonNumeraireAsset, 51);
        vm.etch(newERC4626Address, address(newERC4626Asset.asset).code);
        newERC4626Asset.asset = IERC20(newERC4626Address);
    }
}
