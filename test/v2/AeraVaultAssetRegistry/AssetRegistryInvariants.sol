// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import "./TestBaseAssetRegistry.sol";
import "./handlers/AssetRegistryHandler.sol";

contract AssetRegistryInvariants is TestBaseAssetRegistry {
    AssetRegistryHandler public handler;

    function setUp() public override {
        _deploy();
        handler = new AssetRegistryHandler(AeraVaultAssetRegistry(assetRegistry));
        targetContract(address(handler));
    }

    function invariant_assetCount() public {
        assertEq(handler.assetCount(), assetRegistry.assets().length);
    }
}