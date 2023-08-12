// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/ERC165.sol";
import "@openzeppelin/ERC165Checker.sol";
import "@openzeppelin/IERC20Metadata.sol";
import "@openzeppelin/IERC4626.sol";
import "@openzeppelin/Ownable2Step.sol";
import "./interfaces/IAssetRegistry.sol";
import "./interfaces/ICustody.sol";
import {ONE} from "./Constants.sol";

/// @title Aera Vault Asset Registry.
contract AeraVaultAssetRegistry is IAssetRegistry, ERC165, Ownable2Step {
    /// @notice Maximum number of assets.
    uint256 public constant MAX_ASSETS = 50;

    /// @notice Fee token.
    IERC20 public immutable feeToken;

    /// STORAGE ///

    /// @notice Array of all active assets for the vault.
    AssetInformation[] internal _assets;

    /// @notice The address of the vault.
    address public custody;

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

    /// @notice Emitted in constructor.
    /// @param owner Address of owner.
    /// @param assets Array of assets & associated info in the registry.
    /// @param numeraireId Index of numeraire asset.
    /// @param feeToken Address of fee token.
    event Created(
        address indexed owner,
        AssetInformation[] assets,
        uint256 numeraireId,
        address feeToken
    );

    /// @notice Emitted when custody is set.
    /// @param custody Address of new custody.
    event SetCustody(address custody);

    /// ERRORS ///

    error Aera__NumberOfAssetsExceedsMaximum(uint256 max);
    error Aera__FeeTokenIsNotRegistered(address feeToken);
    error Aera__NumeraireIndexTooHigh(uint256 numAssets, uint256 index);
    error Aera__AssetOrderIsIncorrect(uint256 index);
    error Aera__AssetRegistryInitialOwnerIsZeroAddress();
    error Aera__ERC20OracleIsZeroAddress(address asset);
    error Aera__ERC4626OracleIsNotZeroAddress(address asset);
    error Aera__UnderlyingAssetIsNotRegistered(
        address asset, address underlyingAsset
    );
    error Aera__AssetIsUnderlyingAssetOfERC4626(address erc4626Asset);
    error Aera__NumeraireAssetIsMarkedAsERC4626();
    error Aera__NumeraireOracleIsNotZeroAddress();
    error Aera__ValueLengthIsNotSame(uint256 numAssets, uint256 numValues);
    error Aera__AssetIsAlreadyRegistered(uint256 index);
    error Aera__AssetNotRegistered(address asset);
    error Aera__CannotRemoveNumeraireAsset(address asset);
    error Aera__CannotRemoveFeeToken(address feeToken);
    error Aera__AssetBalanceIsNotZero(address asset);
    error Aera__CustodyIsAlreadySet();
    error Aera__CustodyIsZeroAddress();
    error Aera__CustodyIsNotValid(address custody);
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
        if (owner_ == address(0)) {
            revert Aera__AssetRegistryInitialOwnerIsZeroAddress();
        }
        uint256 numAssets = assets_.length;

        if (numAssets > MAX_ASSETS) {
            revert Aera__NumberOfAssetsExceedsMaximum(MAX_ASSETS);
        }

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

        for (uint256 i = 1; i < numAssets;) {
            if (assets_[i - 1].asset >= assets_[i].asset) {
                revert Aera__AssetOrderIsIncorrect(i);
            }
            unchecked {
                i++; // gas savings
            }
        }

        for (uint256 i = 0; i < numAssets; i++) {
            if (i != numeraireId_) {
                _checkAssetOracle(assets_[i]);

                if (assets_[i].isERC4626) {
                    _checkUnderlyingAsset(assets_[i], assets_);
                }
            }

            _insertAsset(assets_[i], i);
            unchecked {
                i++; // gas savings
            }
        }

        numeraireId = numeraireId_;
        feeToken = feeToken_;

        _transferOwnership(owner_);
        emit Created(owner_, assets_, numeraireId_, address(feeToken_));
    }

    /// @inheritdoc IAssetRegistry
    function addAsset(AssetInformation calldata asset)
        external
        override
        onlyOwner
    {
        uint256 numAssets = _assets.length;

        if (numAssets == MAX_ASSETS) {
            revert Aera__NumberOfAssetsExceedsMaximum(MAX_ASSETS);
        }

        _checkAssetOracle(asset);

        uint256 i = 0;
        for (; i < numAssets;) {
            if (asset.asset < _assets[i].asset) {
                break;
            }

            if (asset.asset == _assets[i].asset) {
                revert Aera__AssetIsAlreadyRegistered(i);
            }
            unchecked {
                i++; // gas savings
            }
        }

        if (asset.isERC4626) {
            _checkUnderlyingAsset(asset, _assets);
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
        if (IERC20(asset).balanceOf(custody) > 0) {
            revert Aera__AssetBalanceIsNotZero(asset);
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
            numYieldAssets--;
        } else {
            for (uint256 i = 0; i < numAssets; i++) {
                if (
                    _assets[i].isERC4626
                        && IERC4626(address(_assets[i].asset)).asset() == asset
                ) {
                    revert Aera__AssetIsUnderlyingAssetOfERC4626(
                        address(_assets[i].asset)
                    );
                }
            }
        }

        uint256 nextIndex;
        uint256 lastIndex = numAssets - 1;
        // Slide all elements after oldAssetIndex left
        for (uint256 i = oldAssetIndex; i < lastIndex;) {
            nextIndex = i + 1;
            _assets[i] = _assets[nextIndex];
            unchecked {
                i++; // gas savings
            }
        }

        _assets.pop();

        if (oldAssetIndex < numeraireId) {
            numeraireId--;
        }

        emit AssetRemoved(asset);
    }

    /// @inheritdoc IAssetRegistry
    function setCustody(address newCustody) external override onlyOwner {
        if (custody != address(0)) {
            revert Aera__CustodyIsAlreadySet();
        }
        if (newCustody == address(0)) {
            revert Aera__CustodyIsZeroAddress();
        }
        if (
            !ERC165Checker.supportsInterface(
                newCustody, type(ICustody).interfaceId
            )
        ) {
            revert Aera__CustodyIsNotValid(newCustody);
        }

        custody = newCustody;

        emit SetCustody(newCustody);
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
        for (uint256 i = 0; i < numAssets;) {
            if (_assets[i].isERC4626) {
                unchecked {
                    i++; // gas savings
                }
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

            unchecked {
                // gas savings
                index++;
                i++;
            }
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

    /// @notice Check whether underlying asset is listed or not.
    /// @param asset ERC4626 asset to check underlying asset.
    /// @param assets Array of assets.
    function _checkUnderlyingAsset(
        AssetInformation memory asset,
        AssetInformation[] memory assets
    ) internal view {
        uint256 numAssets = assets.length;

        address underlyingAsset = IERC4626(address(asset.asset)).asset();
        uint256 underlyingIndex;

        for (; underlyingIndex < numAssets; underlyingIndex++) {
            if (
                !assets[underlyingIndex].isERC4626
                    && underlyingAsset == address(assets[underlyingIndex].asset)
            ) {
                break;
            }
        }

        if (underlyingIndex == numAssets) {
            revert Aera__UnderlyingAssetIsNotRegistered(
                address(asset.asset), underlyingAsset
            );
        }
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
