// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/ERC165.sol";
import "@openzeppelin/IERC20Metadata.sol";
import "@openzeppelin/IERC4626.sol";
import "@openzeppelin/Ownable.sol";
import "./interfaces/IAssetRegistry.sol";
import {ONE} from "./Constants.sol";

/// @title Aera Vault Asset Registry.
contract AeraVaultAssetRegistry is IAssetRegistry, ERC165, Ownable {
    /// @notice Fee token.
    IERC20 public immutable feeToken;

    /// STORAGE ///

    /// @notice Array of all active assets for the vault.
    AssetInformation[] internal _assets;

    /// @notice The index of the numeraire asset in the assets array.
    uint256 public numeraireId;

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

    error Aera__FeeTokenIsNotRegistered(address feeToken);
    error Aera__NumeraireIndexTooHigh(uint256 numAssets, uint256 index);
    error Aera__AssetOrderIsIncorrect(uint256 index);
    error Aera__ERC20OracleIsZeroAddress(address asset);
    error Aera__ERC4626OracleIsNotZeroAddress(address asset);
    error Aera__UnderlyingAssetIsNotRegistered(
        address asset, address underlyingAsset
    );
    error Aera__UnderlyingAssetIsRegistered(
        address asset, address underlyingAsset
    );
    error Aera__NumeraireAssetIsMarkedAsERC4626();
    error Aera__NumeraireOracleIsNotZeroAddress();
    error Aera__ValueLengthIsNotSame(uint256 numAssets, uint256 numValues);
    error Aera__AssetIsAlreadyRegistered(uint256 index);
    error Aera__AssetNotRegistered(address asset);
    error Aera__CannotRemoveNumeraireAsset(address asset);
    error Aera__CannotRemoveFeeToken(address feeToken);
    error Aera__OraclePriceIsInvalid(uint256 index, int256 actual);

    /// FUNCTIONS ///

    /// @notice Initialize the asset registry contract by providing references to
    ///         asset registry, guardian and other parameters.
    /// @param owner_ The address of initial owner.
    /// @param assets_ List of assets.
    /// @param numeraireId_ Index of numeraire asset.
    /// @param feeToken_ Address of fee token.
    constructor(
        address owner_,
        AssetInformation[] memory assets_,
        uint256 numeraireId_,
        IERC20 feeToken_
    ) {
        uint256 numAssets = assets_.length;

        uint256 feeTokenIndex = 0;
        for (; feeTokenIndex < numAssets; feeTokenIndex++) {
            if (assets_[feeTokenIndex].asset == feeToken_) {
                break;
            }
        }

        if (feeTokenIndex == numAssets) {
            revert Aera__FeeTokenIsNotRegistered(address(feeToken_));
        }

        if (numeraireId_ >= numAssets) {
            revert Aera__NumeraireIndexTooHigh(numAssets, numeraireId_);
        }
        if (assets_[numeraireId_].isERC4626) {
            revert Aera__NumeraireAssetIsMarkedAsERC4626();
        }
        if (address(assets_[numeraireId_].oracle) != address(0)) {
            revert Aera__NumeraireOracleIsNotZeroAddress();
        }

        for (uint256 i = 1; i < numAssets; i++) {
            if (assets_[i - 1].asset >= assets_[i].asset) {
                revert Aera__AssetOrderIsIncorrect(i);
            }
        }

        address asset;
        IERC20 underlyingAsset;
        uint256 underlyingIndex;

        for (uint256 i = 0; i < numAssets; i++) {
            if (i != numeraireId_) {
                _checkAssetOracle(assets_[i]);

                if (assets_[i].isERC4626) {
                    asset = address(assets_[i].asset);
                    underlyingAsset = IERC20(IERC4626(asset).asset());
                    underlyingIndex = 0;

                    for (; underlyingIndex < numAssets; underlyingIndex++) {
                        if (
                            !assets_[underlyingIndex].isERC4626
                                && underlyingAsset
                                    == assets_[underlyingIndex].asset
                        ) {
                            break;
                        }
                    }

                    if (underlyingIndex == numAssets) {
                        revert Aera__UnderlyingAssetIsNotRegistered(
                            asset, address(underlyingAsset)
                        );
                    }
                }
            }

            _insertAsset(assets_[i], i);
        }

        numeraireId = numeraireId_;
        feeToken = feeToken_;

        _transferOwnership(owner_);
    }

    /// @inheritdoc IAssetRegistry
    function addAsset(AssetInformation calldata asset)
        external
        override
        onlyOwner
    {
        _checkAssetOracle(asset);

        uint256 numAssets = _assets.length;

        uint256 i = 0;
        for (; i < numAssets; i++) {
            if (asset.asset < _assets[i].asset) {
                break;
            }

            if (asset.asset == _assets[i].asset) {
                revert Aera__AssetIsAlreadyRegistered(i);
            }
        }

        if (asset.isERC4626) {
            address underlyingAsset = IERC4626(address(asset.asset)).asset();

            if (!_isUnderlyingAssetRegistered(IERC20(underlyingAsset))) {
                revert Aera__UnderlyingAssetIsNotRegistered(
                    address(asset.asset), underlyingAsset
                );
            }
        }

        _insertAsset(asset, i);
    }

    /// @inheritdoc IAssetRegistry
    function removeAsset(address asset) external override onlyOwner {
        if (address(_assets[numeraireId].asset) == asset) {
            revert Aera__CannotRemoveNumeraireAsset(asset);
        }
        if (address(feeToken) == asset) {
            revert Aera__CannotRemoveFeeToken(asset);
        }

        uint256 numAssets = _assets.length;
        uint256 oldAssetIndex = 0;
        for (
            ;
            oldAssetIndex < numAssets
                && address(_assets[oldAssetIndex].asset) != asset;
            oldAssetIndex++
        ) {}

        if (oldAssetIndex >= numAssets) {
            revert Aera__AssetNotRegistered(asset);
        }

        if (_assets[oldAssetIndex].isERC4626) {
            address erc4626Asset = address(_assets[oldAssetIndex].asset);
            address underlyingAsset = IERC4626(erc4626Asset).asset();

            if (_isUnderlyingAssetRegistered(IERC20(underlyingAsset))) {
                revert Aera__UnderlyingAssetIsRegistered(
                    erc4626Asset, underlyingAsset
                );
            }

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

        if (oldAssetIndex < numeraireId) {
            numeraireId--;
        }

        emit AssetRemoved(asset);
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

        uint256 numeraireDecimals =
            IERC20Metadata(address(_assets[numeraireId].asset)).decimals();

        uint256 oracleDecimals;
        uint256 price;
        int256 answer;
        uint256 index;
        for (uint256 i = 0; i < numAssets; i++) {
            if (_assets[i].isERC4626) {
                continue;
            }

            if (i == numeraireId) {
                prices[index] = AssetPriceReading({
                    asset: _assets[i].asset,
                    spotPrice: 10 ** numeraireDecimals
                });
            } else {
                (, answer,,,) = _assets[i].oracle.latestRoundData();

                // Check basic validity
                if (answer <= 0) {
                    revert Aera__OraclePriceIsInvalid(i, answer);
                }

                price = uint256(answer);
                oracleDecimals = _assets[i].oracle.decimals();

                if (oracleDecimals != numeraireDecimals) {
                    price = (price * 10 ** numeraireDecimals)
                        / 10 ** oracleDecimals;
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

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return interfaceId == type(IAssetRegistry).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// INTERNAL FUNCTIONS ///

    /// @notice Ensure non-zero oracle address for ERC20
    ///         and zero oracle address for ERC4626.
    /// @param asset Asset details to check
    function _checkAssetOracle(AssetInformation memory asset) internal pure {
        if (asset.isERC4626) {
            if (address(asset.oracle) != address(0)) {
                revert Aera__ERC4626OracleIsNotZeroAddress(
                    address(asset.asset)
                );
            }
        } else if (address(asset.oracle) == address(0)) {
            revert Aera__ERC20OracleIsZeroAddress(address(asset.asset));
        }
    }

    /// @notice Check whether underlying asset is registered or not.
    /// @param underlyingAsset Address of underlying asset.
    /// @return True if underlying asset is registered.
    function _isUnderlyingAssetRegistered(IERC20 underlyingAsset)
        internal
        view
        returns (bool)
    {
        uint256 numAssets = _assets.length;

        for (uint256 i = 0; i < numAssets; i++) {
            if (_assets[i].asset > underlyingAsset) {
                break;
            }
            if (!_assets[i].isERC4626 && underlyingAsset == _assets[i].asset) {
                return true;
            }
        }

        return false;
    }

    /// @notice Insert asset at the given index in an array of assets.
    /// @param asset New asset details.
    /// @param index Index of the new asset in the array.
    function _insertAsset(
        AssetInformation memory asset,
        uint256 index
    ) internal {
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

            if (index <= numeraireId) {
                numeraireId++;
            }
        }

        if (asset.isERC4626) {
            numYieldAssets++;
        }

        emit AssetAdded(asset);
    }
}
