// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "./dependencies/openzeppelin/Ownable.sol";
import "./interfaces/IAssetRegistry.sol";

/// @title Aera Vault Asset Registry.
contract AeraVaultAssetRegistry is IAssetRegistry, Ownable {
    uint256 internal constant ONE = 10**18;

    /// @notice Minimum period for weight change duration.
    uint256 internal constant MINIMUM_WEIGHT_CHANGE_DURATION = 4 hours;

    /// @notice Largest possible weight change ratio per second.
    /// @dev The increment/decrement factor per one second.
    ///      Increment/decrement factor per n seconds: Fn = f * n
    ///      Weight growth range for n seconds: [1 / Fn - 1, Fn - 1]
    ///      E.g. increment/decrement factor per 2000 seconds is 2
    ///      Weight growth range for 2000 seconds is [-50%, 100%]
    uint256 internal constant MAX_WEIGHT_CHANGE_RATIO = 10**15;

    /// STORAGE ///

    /// @notice Array of all active assets for the vault.
    AssetInformation[] internal _assets;

    /// @notice The index of the numeraire asset in the assets array.
    uint256 public numeraire;

    /// @notice Number of ERC4626 assets. Maintained for more efficient calculation of spotPrices.
    uint256 public numYieldAssets;

    /// EVENTS ///

    /// @notice Emitted when a new asset is added.
    /// @param asset Added asset details.
    event AssetAdded(AssetInformation asset);

    /// @notice Emitted when an asset is removed.
    /// @param asset Address of removed asset.
    event AssetRemoved(address asset);

    /// ERRORS ///

    error Aera__NumeraireIndexTooHigh(uint256 numAssets, uint256 index);
    error Aera__AssetOrderIsIncorrect(uint256 index);
    error Aera__OracleIsZeroAddress(address asset);
    error Aera__NumeraireOracleIsNotZeroAddress();
    error Aera__ValueLengthIsNotSame(uint256 numAssets, uint256 numValues);
    error Aera__AssetIsAlreadyRegistered(uint256 index);
    error Aera__AssetNotRegistered(address asset);
    error Aera__CannotRemoveNumeraireAsset(address asset);
    error Aera__OraclePriceIsInvalid(uint256 index, int256 actual);

    /// FUNCTIONS ///

    constructor(AssetInformation[] memory assets_, uint256 numeraire_) {
        uint256 numAssets = assets_.length;

        if (numeraire_ >= numAssets) {
            revert Aera__NumeraireIndexTooHigh(numAssets, numeraire_);
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
            } else if (address(assets_[i].oracle) == address(0)) {
                revert Aera__OracleIsZeroAddress(address(assets_[i].asset));
            }

            _insertAsset(assets_[i], i);
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

        uint256 numAssets = _assets.length;

        uint256 i = 0;
        for (; i < numAssets; i++) {
            if (asset.asset >= _assets[i].asset) {
                if (asset.asset == _assets[i].asset) {
                    revert Aera__AssetIsAlreadyRegistered(i);
                }
            } else {
                break;
            }
        }

        _insertAsset(asset, i);
    }

    /// @inheritdoc IAssetRegistry
    function removeAsset(address asset) external override onlyOwner {
        if (address(_assets[numeraire].asset) == asset) {
            revert Aera__CannotRemoveNumeraireAsset(asset);
        }

        uint256 numAssets = _assets.length;
        uint256 oldAssetIndex = 0;
        for (
            ;
            oldAssetIndex < numAssets &&
                address(_assets[oldAssetIndex].asset) != asset;
            oldAssetIndex++
        ) {}

        if (oldAssetIndex >= numAssets) {
            revert Aera__AssetNotRegistered(asset);
        }

        if (_assets[oldAssetIndex].isERC4626) {
            numYieldAssets--;
        }

        uint256 nextIndex;
        uint256 lastIndex = numAssets - 1;
        // Slide all elements after oldAssetIndex left
        for (uint256 i = oldAssetIndex; i < lastIndex; i++) {
            nextIndex = i + 1;
            _assets[i] = _assets[nextIndex];
        }

        _assets.pop();

        if (oldAssetIndex < numeraire) {
            numeraire--;
        }

        emit AssetRemoved(asset);
    }

    /// @inheritdoc IAssetRegistry
    function checkWeights(
        AssetWeight[] calldata currentWeights,
        AssetWeight[] calldata targetWeights,
        uint256 duration
    ) external view override returns (bool) {
        if (duration < MINIMUM_WEIGHT_CHANGE_DURATION) {
            return false;
        }

        uint256 numAssets = _assets.length;

        if (
            numAssets != currentWeights.length ||
            numAssets != targetWeights.length
        ) {
            return false;
        }

        uint256 maximumRatio = MAX_WEIGHT_CHANGE_RATIO * duration;

        uint256 weightSum = 0;
        for (uint256 i = 0; i < numAssets; i++) {
            uint256 changeRatio = _getWeightChangeRatio(
                currentWeights[i].weight,
                targetWeights[i].weight
            );

            if (changeRatio > maximumRatio) {
                return false;
            }

            weightSum += targetWeights[i].weight;
        }

        if (weightSum != ONE) {
            return false;
        }

        return true;
    }

    /// @inheritdoc IAssetRegistry
    function assets()
        external
        view
        override
        returns (AssetInformation[] memory)
    {
        return _assets;
    }

    /// @inheritdoc IAssetRegistry
    function spotPrices()
        external
        view
        override
        returns (AssetPriceReading[] memory)
    {
        uint256 numAssets = _assets.length;
        AssetPriceReading[] memory prices = new AssetPriceReading[](
            numAssets - numYieldAssets
        );

        uint256 price;
        int256 answer;
        uint256 oracleUnit;
        uint256 index;
        for (uint256 i = 0; i < numAssets; i++) {
            if (_assets[i].isERC4626) {
                continue;
            }

            if (i == numeraire) {
                prices[index] = AssetPriceReading({
                    asset: _assets[i].asset,
                    spotPrice: ONE
                });
            } else {
                (, answer, , , ) = _assets[i].oracle.latestRoundData();

                // Check basic validity
                if (answer <= 0) {
                    revert Aera__OraclePriceIsInvalid(i, answer);
                }

                price = uint256(answer);
                oracleUnit = 10**_assets[i].oracle.decimals();

                if (oracleUnit != ONE) {
                    price = (price * ONE) / oracleUnit;
                }

                prices[index] = AssetPriceReading({
                    asset: _assets[i].asset,
                    spotPrice: price
                });
            }

            index++;
        }

        return prices;
    }

    /// INTERNAL FUNCTIONS ///

    /// @notice Insert asset at the given index in an array of assets.
    /// @dev Will only be called by constructor() and addAsset().
    /// @param asset New asset details.
    /// @param index Index of the new asset in the array.
    function _insertAsset(AssetInformation memory asset, uint256 index)
        internal
    {
        uint256 numAssets = _assets.length;

        if (index == numAssets) {
            _assets.push(asset);
        } else {
            _assets.push(_assets[numAssets - 1]);

            uint256 prevIndex;
            for (uint256 i = numAssets - 1; i > index; i--) {
                prevIndex = i - 1;
                _assets[i] = _assets[prevIndex];
            }

            _assets[index] = asset;

            if (index <= numeraire) {
                numeraire++;
            }
        }

        if (asset.isERC4626) {
            numYieldAssets++;
        }

        emit AssetAdded(asset);
    }

    /// @notice Calculate a change ratio for weight upgrade.
    /// @dev Will only be called by checkWeights().
    /// @param currentWeight Current weight.
    /// @param targetWeight Target weight.
    /// @return ratio Change ratio(>1) from current weight to target weight.
    function _getWeightChangeRatio(uint256 currentWeight, uint256 targetWeight)
        internal
        pure
        returns (uint256 ratio)
    {
        return
            currentWeight > targetWeight
                ? (ONE * currentWeight) / targetWeight
                : (ONE * targetWeight) / currentWeight;
    }
}
