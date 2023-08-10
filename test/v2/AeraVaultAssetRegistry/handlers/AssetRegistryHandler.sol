// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {CommonBase} from "forge-std/Base.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {StdUtils} from "forge-std/StdUtils.sol";

import "src/v2/AeraVaultAssetRegistry.sol";
import "src/v2/interfaces/IAssetRegistry.sol";

contract AssetRegistryHandler is CommonBase, StdCheats, StdUtils {
    AeraVaultAssetRegistry public assetRegistry;
    uint256 public assetCount;

    constructor(AeraVaultAssetRegistry _assetRegistry) {
        assetRegistry = _assetRegistry;
        assetCount = assetRegistry.assets().length;
    }

    function addERC20Asset(
        address assetAddress,
        address oracleAddress
    ) public {
        // This handler will not use the asset registry for getting spot prices
        // so we can use random addresses for asset information
        IAssetRegistry.AssetInformation memory asset = IAssetRegistry
            .AssetInformation({
            asset: IERC20(assetAddress),
            isERC4626: false,
            oracle: AggregatorV2V3Interface(oracleAddress)
        });

        // Action
        address owner = assetRegistry.owner();
        vm.prank(owner);
        assetRegistry.addAsset(asset);

        // Update invariant
        assetCount += 1;
    }

    // TODO: Use more elegant "countCall" pattern
    // TODO: Add remove asset
    // TODO: Add invariant counters and ghost variables
    // TODO: Add remove asset support
}
