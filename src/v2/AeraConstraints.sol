// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "@openzeppelin/ERC165.sol";
import "@openzeppelin/ERC165Checker.sol";
import "@openzeppelin/Ownable.sol";
import "./interfaces/IConstraints.sol";
import {ONE} from "./Constants.sol";

/// @title Aera Constraints contract.
contract AeraConstraints is IConstraints, ERC165, Ownable {
    /// @notice Minimum period for weight change duration.
    uint256 internal constant _MINIMUM_WEIGHT_CHANGE_DURATION = 4 hours;

    /// @notice Largest possible weight change ratio per second.
    /// @dev The increment/decrement factor per one second.
    ///      Increment/decrement factor per n seconds: Fn = f * n
    ///      Weight growth range for n seconds: [1 / Fn - 1, Fn - 1]
    ///      E.g. increment/decrement factor per 2000 seconds is 2
    ///      Weight growth range for 2000 seconds is [-50%, 100%]
    uint256 internal constant _MAX_WEIGHT_CHANGE_RATIO = 0.001e18;

    /// STORAGE ///

    /// @notice The address of asset registry.
    IAssetRegistry public assetRegistry;

    /// @notice The address of custody module.
    ICustody public custody;

    /// FUNCTIONS ///

    /// @notice Initialize the custody contract by providing references to
    ///         asset registry, custody contracts.
    /// @param assetRegistry_ The address of asset registry.
    constructor(address assetRegistry_) {
        _setAssetRegistry(assetRegistry_);
    }

    /// @inheritdoc IConstraints
    function setAssetRegistry(address newAssetRegistry)
        external
        virtual
        override
        onlyOwner
    {
        _setAssetRegistry(newAssetRegistry);
    }

    /// @inheritdoc IConstraints
    function setCustody(address newCustody)
        external
        virtual
        override
        onlyOwner
    {
        _checkCustodyAddress(newCustody);

        custody = ICustody(newCustody);

        emit SetCustody(newCustody);
    }

    /// @inheritdoc IConstraints
    function checkWeights(
        AssetWeight[] calldata currentWeights,
        AssetWeight[] calldata targetWeights,
        uint256 duration
    ) external view override returns (bool) {
        if (duration < _MINIMUM_WEIGHT_CHANGE_DURATION) {
            return false;
        }

        uint256 numAssets = assetRegistry.assets().length;

        if (
            numAssets != currentWeights.length
                || numAssets != targetWeights.length
        ) {
            return false;
        }

        uint256 maximumRatio = _MAX_WEIGHT_CHANGE_RATIO * duration;

        uint256 weightSum = 0;
        for (uint256 i = 0; i < numAssets; i++) {
            uint256 changeRatio = _getWeightChangeRatio(
                currentWeights[i].weight, targetWeights[i].weight
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

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return interfaceId == type(IConstraints).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// INTERNAL FUNCTIONS ///

    /// @notice Sets current asset registry.
    /// @param newAssetRegistry Address of new asset registry.
    function _setAssetRegistry(address newAssetRegistry) internal {
        _checkAssetRegistryAddress(newAssetRegistry);

        assetRegistry = IAssetRegistry(newAssetRegistry);

        emit SetAssetRegistry(newAssetRegistry);
    }

    /// @notice Check if the address can be an asset registry.
    /// @param newAssetRegistry Address to check.
    function _checkAssetRegistryAddress(address newAssetRegistry)
        internal
        view
    {
        if (newAssetRegistry == address(0)) {
            revert Aera__AssetRegistryIsZeroAddress();
        }
        if (
            !ERC165Checker.supportsInterface(
                newAssetRegistry, type(IAssetRegistry).interfaceId
            )
        ) {
            revert Aera__AssetRegistryIsNotValid(newAssetRegistry);
        }
    }

    /// @notice Check if the address can be a custody.
    /// @param newCustody Address to check.
    function _checkCustodyAddress(address newCustody) internal view {
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
    }

    /// @notice Calculate a change ratio for weight upgrade.
    /// @param currentWeight Current weight.
    /// @param targetWeight Target weight.
    /// @return ratio Change ratio(>1) from current weight to target weight.
    function _getWeightChangeRatio(
        uint256 currentWeight,
        uint256 targetWeight
    ) internal pure returns (uint256 ratio) {
        return currentWeight > targetWeight
            ? (ONE * currentWeight) / targetWeight
            : (ONE * targetWeight) / currentWeight;
    }
}
