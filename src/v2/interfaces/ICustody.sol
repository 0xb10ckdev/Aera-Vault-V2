// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../dependencies/openzeppelin/IERC20.sol";
import "./IAssetRegistry.sol";
import "./IExecution.sol";

/// @title Interface for custody module.
interface ICustody {
    /// TYPES ///

    /// @param asset Address of asset.
    /// @param value Value of asset.
    struct AssetValue {
        IERC20 asset;
        uint256 value;
    }

    /// FUNCTIONS ///

    function deposit(AssetValue[] memory amounts) external;

    function withdraw(AssetValue[] memory amounts, bool force) external;

    function setGuardian(address guardian) external;

    function setAssetRegistry(address assetRegistry) external;

    function setExecution(address execution) external;

    function finalize() external;

    function sweep(IERC20 token, uint256 amount) external;

    function pauseVault() external;

    function resumeVault() external;

    function endRebalance() external;

    function endRebalanceEarly() external;

    function startRebalance(
        AssetValue[] memory assetWeights,
        uint256 startTime,
        uint256 endTime
    ) external;

    function claimGuardianFees() external;

    function guardian() external view returns (address guardian);

    function execution() external view returns (IExecution execution);

    function assetRegistry()
        external
        view
        returns (IAssetRegistry assetRegistry);

    function holdings()
        external
        view
        returns (AssetValue[] memory assetAmounts);

    function guardianFee() external view returns (uint256);
}
