// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "./dependencies/openzeppelin/ERC165Checker.sol";
import "./dependencies/openzeppelin/Math.sol";
import "./dependencies/openzeppelin/Ownable.sol";
import "./dependencies/openzeppelin/Pausable.sol";
import "./dependencies/openzeppelin/ReentrancyGuard.sol";
import "./dependencies/openzeppelin/SafeERC20.sol";
import "./interfaces/IAssetRegistry.sol";
import "./interfaces/ICustody.sol";
import "./interfaces/IExecution.sol";
import {ONE} from "./Constants.sol";

/// @title Aera Custody contract.
contract AeraCustody is ICustody, Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Largest possible guardian fee earned proportion per one second.
    /// @dev 0.0000001% per second, i.e. 3.1536% per year.
    ///      0.0000001% * (365 * 24 * 60 * 60) = 3.1536%
    uint256 private constant _MAX_GUARDIAN_FEE = 10 ** 9;

    /// @notice Guardian fee per second in 18 decimal fixed point format.
    uint256 public immutable guardianFee;

    /// STORAGE ///

    /// @notice The address of asset registry.
    IAssetRegistry public assetRegistry;

    /// @notice The address of execution module.
    IExecution public execution;

    /// @notice The address of guardian.
    address public guardian;

    /// @notice Indicates that the Vault has been finalized.
    bool public finalized;

    /// @notice Timestamp at when rebalancing ends.
    uint256 public rebalanceEndTime;

    /// @notice Fee earned amount for each guardian.
    mapping(address => AssetValue[]) public guardiansFee;

    /// @notice Total guardian fee earned amount.
    mapping(IERC20 => uint256) public guardiansFeeTotal;

    /// @notice Last timestamp where guardian fee index was locked.
    uint256 public lastFeeCheckpoint = type(uint256).max;

    /// MODIFIERS ///

    /// @dev Throws if called by any account other than the guardian.
    modifier onlyGuardian() {
        if (msg.sender != guardian) {
            revert Aera__CallerIsNotGuardian();
        }
        _;
    }

    /// @dev Throws if called by any account other than the owner or guardian.
    modifier onlyOwnerOrGuardian() {
        if (msg.sender != owner() && msg.sender != guardian) {
            revert Aera__CallerIsNotOwnerOrGuardian();
        }
        _;
    }

    /// @dev Throws if called after the vault is finalized.
    modifier whenNotFinalized() {
        if (finalized) {
            revert Aera__VaultIsFinalized();
        }
        _;
    }

    /// FUNCTIONS ///

    /// @notice Initialize the custody contract by providing references to
    ///         asset registry, execution contracts and other parameters.
    /// @param assetRegistry_ The address of asset registry.
    /// @param execution_ The address of execution module.
    /// @param guardian_ The address of guardian.
    /// @param guardianFee_ Guardian fee per second in 18 decimal fixed point format.
    constructor(
        address assetRegistry_,
        address execution_,
        address guardian_,
        uint256 guardianFee_
    ) {
        _checkAssetRegistryAddress(assetRegistry_);
        _checkExecutionAddress(execution_);
        _checkGuardianAddress(guardian_);

        if (guardianFee_ > _MAX_GUARDIAN_FEE) {
            revert Aera__GuardianFeeIsAboveMax(guardianFee_, _MAX_GUARDIAN_FEE);
        }

        assetRegistry = IAssetRegistry(assetRegistry_);
        execution = IExecution(execution_);
        guardian = guardian_;
        guardianFee = guardianFee_;
        lastFeeCheckpoint = block.timestamp;

        emit SetAssetRegistry(assetRegistry_);
        emit SetExecution(execution_);
        emit SetGuardian(guardian_);
    }

    /// @inheritdoc ICustody
    function deposit(
        AssetValue[] calldata amounts
    ) external virtual override nonReentrant onlyOwner whenNotFinalized {
        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();
        uint256 numAmounts = amounts.length;
        AssetValue memory assetValue;
        bool isRegistered;

        for (uint256 i = 0; i < numAmounts; i++) {
            assetValue = amounts[i];
            (isRegistered, ) = _isAssetRegistered(assetValue.asset, assets);

            if (!isRegistered) {
                revert Aera__AssetIsNotRegistered(assetValue.asset);
            }

            for (uint256 j = 0; j < numAmounts; j++) {
                if (i != j && assetValue.asset == amounts[j].asset) {
                    revert Aera__AssetIsDuplicated(assetValue.asset);
                }
            }

            assetValue.asset.safeTransferFrom(
                owner(),
                address(this),
                assetValue.value
            );
        }

        emit Deposit(amounts);
    }

    /// @inheritdoc ICustody
    function withdraw(
        AssetValue[] calldata amounts,
        bool force
    ) external virtual override nonReentrant onlyOwner whenNotFinalized {
        _updateGuardianFees();

        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();

        uint256 numAssets = assets.length;
        uint256 numAmounts = amounts.length;
        bool isRegistered;
        AssetValue memory assetValue;

        for (uint256 i = 0; i < numAmounts; i++) {
            assetValue = amounts[i];
            (isRegistered, ) = _isAssetRegistered(assetValue.asset, assets);

            if (!isRegistered) {
                revert Aera__AssetIsNotRegistered(assetValue.asset);
            }

            for (uint256 j = 0; j < numAmounts; j++) {
                if (i != j && assetValue.asset == amounts[j].asset) {
                    revert Aera__AssetIsDuplicated(assetValue.asset);
                }
            }
        }

        for (uint256 i = 0; i < numAmounts; i++) {
            assetValue = amounts[i];

            if (assetValue.asset.balanceOf(address(this)) < assetValue.value) {
                if (!force) {
                    revert Aera__AmountExceedsAvailable(
                        assetValue.asset,
                        assetValue.value,
                        assetValue.asset.balanceOf(address(this))
                    );
                }

                execution.claimNow();
                break;
            }
        }

        for (uint256 i = 0; i < numAssets; i++) {
            if (amounts[i].value > 0) {
                assets[i].asset.safeTransfer(owner(), amounts[i].value);
            }
        }

        emit Withdraw(amounts, force);
    }

    /// @inheritdoc ICustody
    function setGuardian(
        address newGuardian
    ) external virtual override onlyOwner whenNotFinalized {
        _checkGuardianAddress(newGuardian);
        _updateGuardianFees();

        guardian = newGuardian;

        emit SetGuardian(newGuardian);
    }

    /// @inheritdoc ICustody
    function setAssetRegistry(
        address newAssetRegistry
    ) external virtual override onlyOwner whenNotFinalized {
        _checkAssetRegistryAddress(newAssetRegistry);
        _updateGuardianFees();

        assetRegistry = IAssetRegistry(newAssetRegistry);

        emit SetAssetRegistry(newAssetRegistry);
    }

    /// @inheritdoc ICustody
    function setExecution(
        address newExecution
    ) external virtual override onlyOwner whenNotFinalized {
        _checkExecutionAddress(newExecution);

        // Note: we could remove this but leaving it to protect the guardian
        _updateGuardianFees();

        execution = IExecution(newExecution);

        emit SetExecution(newExecution);
    }

    /// @inheritdoc ICustody
    function finalize()
        external
        virtual
        override
        nonReentrant
        onlyOwner
        whenNotFinalized
    {
        finalized = true;

        _updateGuardianFees();

        execution.claimNow();

        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();
        AssetValue[] memory assetAmounts = _getHoldings(assets);
        uint256 numAssetAmounts = assetAmounts.length;

        for (uint256 i = 0; i < numAssetAmounts; i++) {
            assetAmounts[i].asset.safeTransfer(owner(), assetAmounts[i].value);
        }

        emit Finalized();
    }

    /// @inheritdoc ISweepable
    function sweep(
        IERC20 token,
        uint256 amount
    ) external virtual override nonReentrant {
        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();

        (bool isRegistered, ) = _isAssetRegistered(token, assets);

        if (isRegistered) {
            revert Aera__CannotSweepRegisteredAsset();
        }

        token.safeTransfer(owner(), amount);

        emit Sweep(token, amount);
    }

    /// @inheritdoc ICustody
    function pauseVault()
        external
        virtual
        override
        onlyOwner
        whenNotPaused
        whenNotFinalized
    {
        _updateGuardianFees();

        execution.claimNow();

        _pause();
    }

    /// @inheritdoc ICustody
    function resumeVault()
        external
        virtual
        override
        onlyOwner
        whenPaused
        whenNotFinalized
    {
        lastFeeCheckpoint = block.timestamp;

        _unpause();
    }

    /// @inheritdoc ICustody
    function startRebalance(
        AssetValue[] calldata assetWeights,
        uint256 startTime,
        uint256 endTime
    )
        external
        virtual
        override
        nonReentrant
        onlyGuardian
        whenNotPaused
        whenNotFinalized
    {
        _updateGuardianFees();

        uint256 numWeights = assetWeights.length;

        IExecution.AssetRebalanceRequest[]
            memory requests = new IExecution.AssetRebalanceRequest[](
                numWeights
            );

        AssetValue memory assetWeight;

        for (uint256 i = 0; i < numWeights; i++) {
            assetWeight = assetWeights[i];

            requests[i] = IExecution.AssetRebalanceRequest(
                assetWeight.asset,
                assetWeight.asset.balanceOf(address(this)),
                assetWeight.value
            );
            _setAllowance(
                assetWeight.asset,
                address(execution),
                assetWeight.asset.balanceOf(address(this))
            );
        }

        rebalanceEndTime = endTime;

        execution.startRebalance(requests, startTime, endTime);

        emit StartRebalance(assetWeights, startTime, endTime);
    }

    /// @inheritdoc ICustody
    function endRebalance()
        external
        virtual
        override
        nonReentrant
        onlyOwnerOrGuardian
        whenNotPaused
        whenNotFinalized
    {
        if (rebalanceEndTime == 0) {
            revert Aera__RebalancingHasNotStarted();
        }
        if (block.timestamp < rebalanceEndTime) {
            revert Aera__RebalancingIsOnGoing(rebalanceEndTime);
        }

        _updateGuardianFees();

        execution.endRebalance();

        emit EndRebalance();
    }

    /// @inheritdoc ICustody
    function endRebalanceEarly()
        external
        virtual
        override
        nonReentrant
        onlyOwnerOrGuardian
        whenNotPaused
        whenNotFinalized
    {
        _updateGuardianFees();

        execution.claimNow();

        emit EndRebalanceEarly();
    }

    /// @inheritdoc ICustody
    function claimGuardianFees() external override nonReentrant {
        if (msg.sender == guardian) {
            _updateGuardianFees();
        }

        AssetValue[] storage fees = guardiansFee[msg.sender];
        uint256 numFees = fees.length;

        if (numFees == 0) {
            revert Aera__NoAvailableFeeForCaller(msg.sender);
        }

        AssetValue[] memory claimedFees = new AssetValue[](numFees);
        AssetValue storage fee;
        uint256 availableFee;
        bool allFeesClaimed = true;

        for (uint256 i = 0; i < numFees; i++) {
            fee = fees[i];
            claimedFees[i].asset = fee.asset;

            if (fee.value == 0) {
                continue;
            }

            availableFee = Math.min(
                fee.asset.balanceOf(address(this)),
                fee.value
            );
            guardiansFeeTotal[fee.asset] -= availableFee;
            fee.value -= availableFee;
            fee.asset.safeTransfer(msg.sender, availableFee);
            claimedFees[i].value = availableFee;

            if (fee.value > 0) {
                allFeesClaimed = false;
            }
        }

        if (allFeesClaimed && msg.sender != guardian) {
            delete guardiansFee[msg.sender];
        }

        emit ClaimGuardianFees(msg.sender, claimedFees);
    }

    /// @inheritdoc ICustody
    function holdings()
        public
        view
        virtual
        override
        returns (AssetValue[] memory assetAmounts)
    {
        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();

        return _getHoldings(assets);
    }

    /// INTERNAL FUNCTIONS ///

    /// @notice Calculate guardian fee index.
    /// @return feeIndex Guardian fee index.
    function _getFeeIndex() internal view returns (uint256 feeIndex) {
        if (block.timestamp > lastFeeCheckpoint) {
            feeIndex = block.timestamp - lastFeeCheckpoint;
        }

        return feeIndex;
    }

    /// @notice Calculate current guardian fees.
    function _updateGuardianFees() internal {
        if (guardianFee == 0) {
            return;
        }

        uint256 feeIndex = _getFeeIndex();

        if (feeIndex == 0) {
            return;
        }

        IAssetRegistry.AssetInformation[] memory assets = assetRegistry
            .assets();
        AssetValue[] memory assetAmounts = _getHoldings(assets);

        lastFeeCheckpoint = block.timestamp;

        uint256 numAssets = assets.length;
        uint256 numGuardiansFee = guardiansFee[guardian].length;
        AssetValue memory assetAmount;
        uint256 newFee;

        for (uint256 i = 0; i < numAssets; i++) {
            assetAmount = assetAmounts[i];
            newFee = (assetAmount.value * feeIndex * guardianFee) / ONE;
            uint256 j;
            for (; j < numGuardiansFee; j++) {
                if (guardiansFee[guardian][j].asset == assetAmount.asset) {
                    guardiansFee[guardian][j].value += newFee;
                    break;
                }
            }
            if (j == numGuardiansFee) {
                guardiansFee[guardian].push(
                    AssetValue(assetAmount.asset, newFee)
                );
            }

            guardiansFeeTotal[assetAmount.asset] += newFee;
        }
    }

    /// @notice Get total amount of assets in execution and custody module.
    /// @param assets Struct details for registered assets in asset registry.
    /// @return assetAmounts Amount of assets.
    function _getHoldings(
        IAssetRegistry.AssetInformation[] memory assets
    ) internal view returns (AssetValue[] memory assetAmounts) {
        IExecution.AssetValue[] memory executionHoldings = execution.holdings();

        uint256 numAssets = assets.length;
        uint256 numExecutionHoldings = executionHoldings.length;

        assetAmounts = new AssetValue[](numAssets);
        IAssetRegistry.AssetInformation memory asset;

        for (uint256 i = 0; i < numAssets; i++) {
            asset = assets[i];
            assetAmounts[i] = AssetValue({
                asset: asset.asset,
                value: asset.asset.balanceOf(address(this))
            });
        }

        IExecution.AssetValue memory executionHolding;

        for (uint256 i = 0; i < numExecutionHoldings; i++) {
            executionHolding = executionHoldings[i];

            for (uint256 j = 0; j < numAssets; j++) {
                if (assets[j].asset < executionHolding.asset) {
                    continue;
                }
                if (assets[j].asset == executionHolding.asset) {
                    assetAmounts[j].value += executionHolding.value;
                }
                break;
            }
        }

        for (uint256 i = 0; i < numAssets; i++) {
            assetAmounts[i].value -= guardiansFeeTotal[assets[i].asset];
        }
    }

    /// @notice Reset allowance of token for a spender.
    /// @param token Token of address to set allowance.
    /// @param spender Address to give spend approval to.
    function _clearAllowance(IERC20 token, address spender) internal {
        uint256 allowance = token.allowance(address(this), spender);
        if (allowance > 0) {
            token.safeDecreaseAllowance(spender, allowance);
        }
    }

    /// @notice Set allowance of token for a spender.
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

    /// @notice Check if the address can be a guardian.
    /// @param newGuardian Address to check.
    function _checkGuardianAddress(address newGuardian) internal view {
        if (newGuardian == address(0)) {
            revert Aera__GuardianIsZeroAddress();
        }
        if (newGuardian == owner()) {
            revert Aera__GuardianIsOwner();
        }
    }

    /// @notice Check if the address can be an asset registry.
    /// @param newAssetRegistry Address to check.
    function _checkAssetRegistryAddress(
        address newAssetRegistry
    ) internal view {
        if (newAssetRegistry == address(0)) {
            revert Aera__AssetRegistryIsZeroAddress();
        }
        if (
            !ERC165Checker.supportsInterface(
                newAssetRegistry,
                type(IAssetRegistry).interfaceId
            )
        ) {
            revert Aera__AssetRegistryIsNotValid(newAssetRegistry);
        }
    }

    /// @notice Check if the address can be an execution.
    /// @param newExecution Address to check.
    function _checkExecutionAddress(
        address newExecution
    ) internal view virtual {
        if (newExecution == address(0)) {
            revert Aera__ExecutionIsZeroAddress();
        }
        if (
            !ERC165Checker.supportsInterface(
                newExecution,
                type(IExecution).interfaceId
            )
        ) {
            revert Aera__ExecutionIsNotValid(newExecution);
        }
    }

    /// @notice Check whether asset is registered to asset registry or not.
    /// @param asset Asset to check.
    /// @param registeredAssets Array of registered assets.
    /// @return isRegistered True if asset is registered.
    /// @return index Index of asset in Balancer pool.
    function _isAssetRegistered(
        IERC20 asset,
        IAssetRegistry.AssetInformation[] memory registeredAssets
    ) internal pure returns (bool isRegistered, uint256 index) {
        uint256 numAssets = registeredAssets.length;

        for (uint256 i = 0; i < numAssets; i++) {
            if (registeredAssets[i].asset < asset) {
                continue;
            }
            if (registeredAssets[i].asset == asset) {
                return (true, i);
            }
            break;
        }
    }
}
