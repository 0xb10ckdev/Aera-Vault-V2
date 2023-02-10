// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./dependencies/openzeppelin/Ownable.sol";
import "./interfaces/IAssetRegistry.sol";

/// @title Aera Vault Asset Registry.
contract AeraVaultAssetRegistry is IAssetRegistry, Ownable {
    /// STORAGE ///

    uint256 internal constant ONE = 10**18;

    /// @notice Array of all active assets for the vault.
    AssetInformation[] internal assets;

    /// @notice Units in oracle decimals.
    uint256[] public oracleUnits;

    /// @notice The index of the numeraire asset in the assets array.
    uint256 public numeraire;

    /// @notice Number of ERC4626 assets.
    uint256 public numYieldAssets;

    /// EVENTS ///

    /// @notice Emitted when a new asset is added.
    /// @param asset Struct asset information.
    event AssetAdded(AssetInformation asset);

    /// @notice Emitted when an asset is removed.
    /// @param asset Address of an asset.
    event AssetRemoved(address asset);

    /// ERRORS ///

    error Aera__NumeraireAssetIndexExceedsAssetLength(
        uint256 numAsset,
        uint256 index
    );
    error Aera__AssetOrderIsIncorrect(uint256 index);
    error Aera__OracleIsZeroAddress(address asset);
    error Aera__NumeraireOracleIsNotZeroAddress();
    error Aera__ValueLengthIsNotSame(uint256 numAssets, uint256 numValues);
    error Aera__SumOfWeightIsNotOne();
    error Aera__AssetIsAlreadyRegistered(uint256 index);
    error Aera__NoAssetIsRegistered(address asset);
    error Aera__CannotRemoveNumeraireAsset(address asset);
    error Aera__OraclePriceIsInvalid(uint256 index, int256 actual);

    /// FUNCTIONS ///

    constructor(AssetInformation[] memory assets_, uint256 numeraire_) {
        uint256 numAssets = assets_.length;

        if (numeraire_ >= numAssets) {
            revert Aera__NumeraireAssetIndexExceedsAssetLength(
                numAssets,
                numeraire_
            );
        }

        for (uint256 i = 1; i < numAssets; i++) {
            if (assets_[i - 1].asset >= assets_[i].asset) {
                revert Aera__AssetOrderIsIncorrect(i);
            }
        }

        for (uint256 i = 0; i < numAssets; i++) {
            if (i == numeraire_) {
                if (address(assets_[i].oracle) != address(0)) {
                    revert Aera__NumeraireOracleIsNotZeroAddress();
                }
                insertAsset(assets_[i], ONE, i);
            } else {
                if (address(assets_[i].oracle) == address(0)) {
                    revert Aera__OracleIsZeroAddress(address(assets_[i].asset));
                }
                insertAsset(assets_[i], 10**assets_[i].oracle.decimals(), i);
            }
        }

        numeraire = numeraire_;
    }

    /// @inheritdoc IAssetRegistry
    function addAsset(AssetInformation calldata asset)
        external
        override
        onlyOwner
    {
        if (address(asset.oracle) == address(0)) {
            revert Aera__OracleIsZeroAddress(address(asset.asset));
        }

        uint256 numAssets = assets.length;
        uint256 newAssetIndex = numAssets;

        for (uint256 i = 0; i != numAssets; ) {
            if (asset.asset < assets[i].asset) {
                newAssetIndex = i;
                break;
            } else if (assets[i].asset == asset.asset) {
                revert Aera__AssetIsAlreadyRegistered(i);
            }

            unchecked {
                ++i;
            }
        }

        insertAsset(asset, 10**asset.oracle.decimals(), newAssetIndex);
    }

    /// @inheritdoc IAssetRegistry
    function removeAsset(address asset) external override onlyOwner {
        if (address(assets[numeraire].asset) == asset) {
            revert Aera__CannotRemoveNumeraireAsset(asset);
        }

        uint256 numAssets = assets.length;
        uint256 oldAssetIndex = numAssets;
        for (uint256 i = 0; i != numAssets; i++) {
            if (address(assets[i].asset) == asset) {
                oldAssetIndex = i;

                break;
            }
        }

        if (oldAssetIndex < numAssets) {
            if (assets[oldAssetIndex].isERC4626) {
                unchecked {
                    --numYieldAssets;
                }
            }

            uint256 nextIndex;
            uint256 lastIndex = numAssets - 1;
            for (uint256 i = oldAssetIndex; i != lastIndex; ) {
                nextIndex = i + 1;
                assets[i] = assets[nextIndex];
                oracleUnits[i] = oracleUnits[nextIndex];
                unchecked {
                    ++i;
                }
            }

            delete assets[lastIndex];
            delete oracleUnits[lastIndex];

            if (oldAssetIndex < numeraire) {
                unchecked {
                    --numeraire;
                }
            }

            emit AssetRemoved(asset);
        } else {
            revert Aera__NoAssetIsRegistered(asset);
        }
    }

    /// @inheritdoc IAssetRegistry
    function checkWeights(
        AssetWeight[] calldata currentWeights,
        AssetWeight[] calldata targetWeights
    ) external view override returns (bool valid) {
        uint256 numAssets = assets.length;

        if (numAssets != currentWeights.length) {
            revert Aera__ValueLengthIsNotSame(numAssets, currentWeights.length);
        }
        if (numAssets != targetWeights.length) {
            revert Aera__ValueLengthIsNotSame(numAssets, targetWeights.length);
        }

        uint256 weightSum = 0;

        for (uint256 i = 0; i != numAssets; ) {
            weightSum += targetWeights[i].weight;

            unchecked {
                ++i;
            }
        }

        if (weightSum != ONE) {
            revert Aera__SumOfWeightIsNotOne();
        }

        return true;
    }

    /// @inheritdoc IAssetRegistry
    function getAssets()
        external
        view
        override
        returns (AssetInformation[] memory)
    {
        return assets;
    }

    /// @inheritdoc IAssetRegistry
    function spotPrices()
        external
        view
        override
        returns (AssetPriceReading[] memory spotPrices)
    {
        uint256 numAssets = assets.length;
        spotPrices = new AssetPriceReading[](numAssets - numYieldAssets);

        uint256 price;
        int256 answer;
        uint256 index;
        for (uint256 i = 0; i != numAssets; ++i) {
            if (assets[i].isERC4626) {
                continue;
            }

            if (i == numeraire) {
                spotPrices[index] = AssetPriceReading({
                    asset: assets[i].asset,
                    spotPrice: ONE
                });
            } else {
                (, answer, , , ) = assets[i].oracle.latestRoundData();

                // Check if the price from the Oracle is valid as Aave does
                if (answer <= 0) {
                    revert Aera__OraclePriceIsInvalid(i, answer);
                }

                price = uint256(answer);

                if (oracleUnits[i] != ONE) {
                    price = (price * ONE) / oracleUnits[i];
                }

                spotPrices[index] = AssetPriceReading({
                    asset: assets[i].asset,
                    spotPrice: price
                });
            }

            unchecked {
                ++index;
            }
        }
    }

    /// @notice Insert asset at a given index in an array of assets.
    /// @dev Will only be called by constructor() and addAsset().
    /// @param asset A new asset to add.
    /// @param oracleUint Unit in oracle decimals.
    /// @param index Index of a new asset in the array.
    function insertAsset(
        AssetInformation memory asset,
        uint256 oracleUint,
        uint256 index
    ) internal {
        uint256 numAssets = assets.length;

        if (index == numAssets) {
            assets.push(asset);
            oracleUnits.push(oracleUint);
        } else {
            assets.push(assets[numAssets - 1]);
            oracleUnits.push(ONE);

            uint256 prevIndex;
            for (uint256 i = numAssets - 1; i != index; ) {
                prevIndex = i - 1;
                assets[i] = assets[prevIndex];
                oracleUnits[i] = oracleUnits[prevIndex];

                unchecked {
                    --i;
                }
            }

            assets[index] = asset;
            oracleUnits[index] = oracleUint;

            if (index <= numeraire) {
                unchecked {
                    ++numeraire;
                }
            }
        }

        if (asset.isERC4626) {
            unchecked {
                ++numYieldAssets;
            }
        }

        emit AssetAdded(asset);
    }
}
