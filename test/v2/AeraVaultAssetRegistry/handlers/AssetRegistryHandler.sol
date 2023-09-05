// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {TestBase} from "test/utils/TestBase.sol";
import {ERC20, ERC4626Mock} from "test/utils/ERC4626Mock.sol";

import "src/v2/AeraVaultAssetRegistry.sol";
import "src/v2/dependencies/openzeppelin/IERC4626.sol";
import "src/v2/interfaces/IAssetRegistry.sol";

contract AssetRegistryHandler is TestBase {
    AeraVaultAssetRegistry public assetRegistry;

    uint256 public assetCount;

    constructor(AeraVaultAssetRegistry assetRegistry_) {
        assetRegistry = assetRegistry_;
        assetCount = assetRegistry.assets().length;
    }

    function addERC20Asset(
        IERC20 assetAddress,
        address oracleAddress
    ) public {
        IAssetRegistry.AssetInformation memory asset = IAssetRegistry
            .AssetInformation({
            asset: assetAddress,
            isERC4626: false,
            oracle: AggregatorV2V3Interface(oracleAddress),
            heartbeat: 1 hours
        });

        vm.prank(assetRegistry.owner());
        assetRegistry.addAsset(asset);

        // Update invariant
        assetCount++;
    }

    function addERC4626Asset(uint256 index) public {
        index %= assetCount;

        IAssetRegistry.AssetInformation[] memory assets =
            assetRegistry.assets();

        ERC4626Mock erc4626Asset;

        for (uint256 i = 0; i < assetCount; i++) {
            uint256 validIndex = (index + i) % assetCount;

            if (!assets[validIndex].isERC4626) {
                erc4626Asset = new ERC4626Mock(
                    ERC20(address(assets[validIndex].asset)),
                    "Mock ERC4626",
                    "MERC4626"
                );
                break;
            }
        }

        IAssetRegistry.AssetInformation memory asset = IAssetRegistry
            .AssetInformation({
            asset: IERC20(address(erc4626Asset)),
            isERC4626: true,
            oracle: AggregatorV2V3Interface(address(0)),
            heartbeat: 1 hours
        });

        vm.prank(assetRegistry.owner());
        assetRegistry.addAsset(asset);

        // Update invariant
        assetCount++;
    }

    function removeERC20Asset(uint256 index) public {
        index %= assetCount;

        IAssetRegistry.AssetInformation[] memory assets =
            assetRegistry.assets();

        address erc20Asset;

        for (uint256 i = 0; i < assetCount; i++) {
            uint256 validIndex = (index + i) % assetCount;

            if (!assets[validIndex].isERC4626) {
                erc20Asset = address(assets[validIndex].asset);
                break;
            }
        }

        vm.startPrank(assetRegistry.owner());

        for (uint256 i = assetCount - 1;; i--) {
            if (
                assets[i].isERC4626
                    && IERC4626(address(assets[i].asset)).asset() == erc20Asset
            ) {
                assetRegistry.removeAsset(address(assets[i].asset));

                // Update invariant
                assetCount--;
            }

            if (i == 0) {
                break;
            }
        }

        assetRegistry.removeAsset(erc20Asset);

        // Update invariant
        assetCount--;
    }

    function removeERC4626Asset(uint256 index) public {
        index %= assetCount;

        IAssetRegistry.AssetInformation[] memory assets =
            assetRegistry.assets();

        address erc4626Asset;

        for (uint256 i = 0; i < assetCount; i++) {
            uint256 validIndex = (index + i) % assetCount;

            if (assets[validIndex].isERC4626) {
                erc4626Asset = address(assets[validIndex].asset);
                break;
            }
        }

        vm.prank(assetRegistry.owner());
        assetRegistry.removeAsset(erc4626Asset);

        // Update invariant
        assetCount--;
    }

    // TODO: Use more elegant "countCall" pattern
    // TODO: Add remove asset
    // TODO: Add invariant counters and ghost variables
    // TODO: Add remove asset support
}
