// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "./TestBaseAssetRegistry.sol";
import "./handlers/AssetRegistryHandler.sol";

contract AssetRegistryInvariantTest is TestBaseAssetRegistry {
    AssetRegistryHandler public handler;

    function setUp() public override {
        super.setUp();

        handler = new AssetRegistryHandler(assetRegistry);

        targetContract(address(handler));
        excludeArtifact("ERC4626Mock");
    }

    function invariant_assetCount() public {
        assertEq(assetRegistry.assets().length, handler.assetCount());
        assertLe(assetRegistry.assets().length, assetRegistry.MAX_ASSETS());
    }

    function invariant_noDuplicateAssets() public {
        IAssetRegistry.AssetInformation[] memory assets =
            assetRegistry.assets();

        for (uint256 i = 0; i < assets.length; i++) {
            for (uint256 j = 0; j < assets.length; j++) {
                if (i != j) {
                    assertNotEq(
                        address(assets[i].asset), address(assets[j].asset)
                    );
                }
            }
        }
    }

    function invariant_oracle() public {
        IAssetRegistry.AssetInformation[] memory assets =
            assetRegistry.assets();

        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i].asset == assetRegistry.numeraireAsset()) {
                assertEq(address(assets[i].oracle), address(0));
            } else if (assets[i].isERC4626) {
                assertEq(address(assets[i].oracle), address(0));
            } else {
                assertNotEq(address(assets[i].oracle), address(0));
            }
        }
    }

    function invariant_numeraireAsset() public {
        IAssetRegistry.AssetInformation[] memory assets =
            assetRegistry.assets();

        assertEq(address(assetRegistry.numeraireAsset()), numeraireAsset);

        bool isRegistered;

        for (uint256 i = 0; i < assets.length; i++) {
            if (address(assets[i].asset) == numeraireAsset) {
                isRegistered = true;
                break;
            }
        }

        assertTrue(isRegistered);
    }

    function invariant_feeToken() public {
        IAssetRegistry.AssetInformation[] memory assets =
            assetRegistry.assets();

        assertEq(address(assetRegistry.feeToken()), address(feeToken));

        bool isRegistered;

        for (uint256 i = 0; i < assets.length; i++) {
            if (address(assets[i].asset) == address(feeToken)) {
                isRegistered = true;
                break;
            }
        }

        assertTrue(isRegistered);
    }

    function invariant_numYieldAssets() public {
        IAssetRegistry.AssetInformation[] memory assets =
            assetRegistry.assets();

        uint256 numYieldAssets;

        for (uint256 i = 0; i < assets.length; i++) {
            if (assets[i].isERC4626) {
                numYieldAssets++;
            }
        }

        assertEq(assetRegistry.numYieldAssets(), numYieldAssets);
    }
}
