// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../dependencies/openzeppelin/IERC20.sol";
import "./IBVault.sol";

interface IBManagedPool {
    function addAllowedAddress(address member) external;

    function addToken(
        IERC20 tokenToAdd,
        address assetManager,
        uint256 tokenToAddNormalizedWeight,
        uint256 mintAmount,
        address recipient
    ) external;

    function removeToken(
        IERC20 tokenToRemove,
        uint256 burnAmount,
        address sender
    ) external;

    function updateWeightsGradually(
        uint256 startTime,
        uint256 endTime,
        IERC20[] calldata tokens,
        uint256[] calldata endWeights
    ) external;

    function setSwapEnabled(bool swapEnabled) external;

    function getPoolId() external view returns (bytes32);

    function getVault() external view returns (IBVault);
}
