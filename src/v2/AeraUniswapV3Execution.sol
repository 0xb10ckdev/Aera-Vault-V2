// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./dependencies/openzeppelin/IERC20Metadata.sol";
import "./dependencies/openzeppelin/Math.sol";
import "./dependencies/openzeppelin/Ownable.sol";
import "./dependencies/openzeppelin/ReentrancyGuard.sol";
import "./dependencies/openzeppelin/SafeERC20.sol";
import "./interfaces/IUniswapV3Execution.sol";
import "./interfaces/IBManagedPool.sol";
import "./interfaces/IBManagedPoolFactory.sol";
import "./interfaces/IBMerkleOrchard.sol";
import "./interfaces/IBVault.sol";

/// @title Aera Balancer Execution.
contract AeraUniswapV3Execution is
    IUniswapV3Execution,
    Ownable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    uint256 internal constant _ONE = 1e18;

    /// @notice The address of asset registry.
    IAssetRegistry public immutable assetRegistry;

    IERC20 public vehicle;
    uint256 public maxSlippage;
    PoolPreference[] public poolPreferences;

    /// STORAGE ///

    /// @notice Describes execution module and which custody vault it is intended for.
    /// @dev string cannot be immutable bytecode but only set in constructor.
    string public description;

    /// @notice Vault contract that the execution layer is linked to.
    address public vault;

    /// @notice Timestamp at when rebalancing ends.
    uint256 public rebalanceEndTime;

    /// ERRORS ///

    error Aera__AssetRegistryIsZeroAddress();
    error Aera__DescriptionIsEmpty();
    error Aera__PoolTokenIsNotRegistered(IERC20 poolToken);
    error Aera__ModuleIsAlreadyInitialized();
    error Aera__VaultIsZeroAddress();
    error Aera__CannotSweepPoolAsset();

    /// MODIFIERS ///

    /// @dev Throws if called by any account other than the vault.
    modifier onlyVault() {
        if (msg.sender != vault) {
            revert Aera__CallerIsNotVault();
        }
        _;
    }

    /// FUNCTIONS ///

    /// @notice Initialize the contract by deploying a new Balancer Pool using the provided factory.
    /// @dev Tokens should be unique.
    ///      The following pre-conditions are checked by Balancer in internal transactions:
    ///       If tokens are sorted in ascending order.
    ///       If swapFeePercentage is greater than the minimum and less than the maximum.
    ///       If the total sum of weights is one.
    /// @param executionParams Struct vault parameter.
    constructor(NewUniswapV3ExecutionParams memory executionParams) {
        if (executionParams.assetRegistry == address(0)) {
            revert Aera__AssetRegistryIsZeroAddress();
        }

        if (bytes(executionParams.description).length == 0) {
            revert Aera__DescriptionIsEmpty();
        }

        IAssetRegistry.AssetInformation[] memory assets = IAssetRegistry(
            executionParams.assetRegistry
        ).assets();

        // TODO: make sure valid ERC20 token
        vehicle = IERC20(executionParams.vehicle);
        // TODO: make sure maxSlippage in valid range
        maxSlippage = executionParams.maxSlippage;
        description = executionParams.description;
        assetRegistry = IAssetRegistry(executionParams.assetRegistry);
    }

    /// @inheritdoc IExecution
    function startRebalance(
        AssetRebalanceRequest[] calldata requests,
        uint256 startTime,
        uint256 endTime
    ) external override nonReentrant onlyVault {
        if (rebalanceEndTime > 0) {
            revert Aera__RebalancingIsOnGoing(rebalanceEndTime);
        }

        _validateRequests(requests, startTime, endTime);

        // TODO

        emit StartRebalance(requests, startTime, endTime);
    }

    /// @inheritdoc IExecution
    function endRebalance() external override nonReentrant onlyVault {
        if (rebalanceEndTime == 0) {
            revert Aera__RebalancingHasNotStarted();
        }
        if (block.timestamp < rebalanceEndTime) {
            revert Aera__RebalancingIsOnGoing(rebalanceEndTime);
        }

        // TODO

        emit EndRebalance();
    }

    /// @inheritdoc IExecution
    function claimNow() external override nonReentrant onlyVault {
        // TODO
        emit ClaimNow();
    }

    /// @inheritdoc IExecution
    function sweep(IERC20 token) external override nonReentrant {
        // TODO

        emit Sweep(token);
    }

    /// @inheritdoc IExecution
    function holdings() public view override returns (AssetValue[] memory) {
        return new AssetValue[](0);
    }

    /// INTERNAL FUNCTIONS ///

    /// @notice Check if the requests are valid.
    /// @dev Will only be called by startRebalance().
    /// @param requests Struct details for requests.
    /// @param startTime Timestamp at which weight movement should start.
    /// @param endTime Timestamp at which the weights should reach target values.
    function _validateRequests(
        AssetRebalanceRequest[] calldata requests,
        uint256 startTime,
        uint256 endTime
    ) internal view {
        uint256 numRequests = requests.length;
        uint256 weightSum = 0;
        for (uint256 i = 0; i < numRequests; i++) {
            weightSum += requests[i].weight;
        }

        if (weightSum != _ONE) {
            revert Aera__SumOfWeightsIsNotOne();
        }

        startTime = Math.max(block.timestamp, startTime);
        if (startTime > endTime) {
            revert Aera__WeightChangeEndBeforeStart();
        }
    }

    /// @notice Reset allowance of token for a spender.
    /// @dev Will only be called by _setAllowance().
    /// @param token Token of address to set allowance.
    /// @param spender Address to give spend approval to.
    function _clearAllowance(IERC20 token, address spender) internal {
        uint256 allowance = token.allowance(address(this), spender);
        if (allowance > 0) {
            token.safeDecreaseAllowance(spender, allowance);
        }
    }

    /// @notice Set allowance of token for a spender.
    /// @dev Will only be called by initialize() and _depositTokenToPool().
    /// @param token Token of address to set allowance.
    /// @param spender Address to give spend approval to.
    /// @param amount Amount to approve for spending.
    function _setAllowance(
        IERC20 token,
        address spender,
        uint256 amount
    ) internal {
        _clearAllowance(token, spender);
        token.safeIncreaseAllowance(spender, amount);
    }
}
