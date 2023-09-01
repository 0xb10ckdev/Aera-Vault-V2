// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/ERC165.sol";
import "@openzeppelin/ERC165Checker.sol";
import "@openzeppelin/IERC4626.sol";
import "@openzeppelin/Math.sol";
import "@openzeppelin/Ownable2Step.sol";
import "@openzeppelin/Pausable.sol";
import "@openzeppelin/ReentrancyGuard.sol";
import "@openzeppelin/SafeERC20.sol";
import "./interfaces/IAeraVaultV2Factory.sol";
import "./interfaces/IHooks.sol";
import "./interfaces/IVault.sol";
import {ONE} from "./Constants.sol";

/// @title AeraVaultV2.
/// @notice Aera Vault V2 Vault contract.
contract AeraVaultV2 is
    IVault,
    ERC165,
    Ownable2Step,
    Pausable,
    ReentrancyGuard
{
    using SafeERC20 for IERC20;

    /// @notice Largest possible fee earned proportion per one second.
    /// @dev 0.0000001% per second, i.e. 3.1536% per year.
    ///      0.0000001% * (365 * 24 * 60 * 60) = 3.1536%
    uint256 private constant _MAX_FEE = 10 ** 9;

    /// @notice Fee per second in 18 decimal fixed point format.
    uint256 public immutable fee;

    /// @notice Asset registry address.
    IAssetRegistry public immutable assetRegistry;

    /// @notice The address of WETH.
    address public immutable weth;

    /// STORAGE ///

    /// @notice Describes vault purpose and modelling assumptions for
    ///         differentiating between vaults.
    /// @dev String cannot be immutable bytecode but only set in constructor
    string public description;

    /// @notice Hooks module address.
    IHooks public hooks;

    /// @notice Guardian address.
    address public guardian;

    /// @notice Fee recipient address.
    address public feeRecipient;

    /// @notice True if vault has been finalized.
    bool public finalized;

    /// @notice Last measured value of assets in vault.
    uint256 public lastValue;

    /// @notice Last spot price of fee token.
    uint256 public lastFeeTokenPrice;

    /// @notice Fee earned amount for each prior fee recipient.
    mapping(address => uint256) public fees;

    /// @notice Total fee earned and unclaimed amount by all fee recipients.
    uint256 public feeTotal;

    /// @notice Last timestamp when fee index was reserved.
    uint256 public lastFeeCheckpoint = type(uint256).max;

    /// MODIFIERS ///

    /// @dev Throws if called by any account other than the owner or guardian.
    modifier onlyOwnerOrGuardian() {
        if (msg.sender != owner() && msg.sender != guardian) {
            revert Aera__CallerIsNotOwnerAndGuardian();
        }
        _;
    }

    /// @dev Throws if called by any account other than the guardian.
    modifier onlyGuardian() {
        if (msg.sender != guardian) {
            revert Aera__CallerIsNotGuardian();
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

    /// @dev Throws if hooks is not set
    modifier whenHooksSet() {
        if (address(hooks) == address(0)) {
            revert Aera__HooksIsZeroAddress();
        }
        _;
    }

    /// @dev Calculate current guardian fees.
    modifier reserveFees() {
        _reserveFees();
        _;
    }

    /// FUNCTIONS ///

    constructor() {
        (
            address owner_,
            address assetRegistry_,
            address guardian_,
            address feeRecipient_,
            uint256 fee_,
            string memory description_
        ) = IAeraVaultV2Factory(msg.sender).parameters();
        address weth_ = IAeraVaultV2Factory(msg.sender).weth();

        // Requirements: check provided addresses.
        _checkAssetRegistryAddress(assetRegistry_);
        _checkGuardianAddress(guardian_);
        _checkFeeRecipientAddress(feeRecipient_);

        // Requirements: check that initial owner is not zero address.
        if (owner_ == address(0)) {
            revert Aera__InitialOwnerIsZeroAddress();
        }
        // Requirements: check if fee is within bounds.
        if (fee_ > _MAX_FEE) {
            revert Aera__FeeIsAboveMax(fee_, _MAX_FEE);
        }
        // Requirements: confirm that vault has a description.
        if (bytes(description_).length == 0) {
            revert Aera__DescriptionIsEmpty();
        }
        if (weth_ == address(0)) {
            revert Aera__WETHIsZeroAddress();
        }

        // Effects: initialize vault state.
        weth = weth_;
        assetRegistry = IAssetRegistry(assetRegistry_);
        guardian = guardian_;
        feeRecipient = feeRecipient_;
        fee = fee_;
        description = description_;
        lastFeeCheckpoint = block.timestamp;

        // Effects: set new owner.
        _transferOwnership(owner_);

        // Effects: pause vault.
        _pause();

        // Log setting of asset registry.
        emit SetAssetRegistry(assetRegistry_);

        // Log the current guardian and fee recipient.
        emit SetGuardianAndFeeRecipient(guardian_, feeRecipient_);
    }

    /// @inheritdoc IVault
    function deposit(AssetValue[] calldata amounts)
        external
        override
        nonReentrant
        onlyOwner
        whenHooksSet
        whenNotFinalized
        reserveFees
    {
        // Hooks: before transferring assets.
        hooks.beforeDeposit(amounts);

        IAssetRegistry.AssetInformation[] memory assets =
            assetRegistry.assets();

        uint256 numAmounts = amounts.length;
        AssetValue memory assetValue;
        bool isRegistered;

        for (uint256 i = 0; i < numAmounts;) {
            assetValue = amounts[i];
            (isRegistered,) = _isAssetRegistered(assetValue.asset, assets);

            // Requirements: check that deposited assets are registered.
            if (!isRegistered) {
                revert Aera__AssetIsNotRegistered(assetValue.asset);
            }

            for (uint256 j = 0; j < numAmounts;) {
                // Requirements: check that no duplicate assets are provided.
                if (i != j && assetValue.asset == amounts[j].asset) {
                    revert Aera__AssetIsDuplicated(assetValue.asset);
                }
                unchecked {
                    j++; // gas savings
                }
            }

            // Interactions: transfer asset from owner to vault.
            assetValue.asset.safeTransferFrom(
                owner(), address(this), assetValue.value
            );

            unchecked {
                i++; // gas savings
            }
        }

        // Hooks: after transferring assets.
        hooks.afterDeposit(amounts);

        // Log deposit.
        emit Deposit(owner(), amounts);
    }

    /// @inheritdoc IVault
    function withdraw(AssetValue[] calldata amounts)
        external
        override
        nonReentrant
        onlyOwner
        whenHooksSet
        whenNotFinalized
        reserveFees
    {
        IAssetRegistry.AssetInformation[] memory assets =
            assetRegistry.assets();

        // Requirements: check the withdraw request.
        _checkWithdrawRequest(assets, amounts);

        // Hooks: before transferring assets.
        hooks.beforeWithdraw(amounts);

        uint256 numAmounts = amounts.length;
        AssetValue memory assetValue;

        for (uint256 i = 0; i < numAmounts; i++) {
            assetValue = amounts[i];

            if (assetValue.value == 0) {
                continue;
            }

            // Interactions: withdraw assets.
            assetValue.asset.safeTransfer(owner(), assetValue.value);
        }

        // Hooks: after transferring assets.
        hooks.afterWithdraw(amounts);

        // Log withdrawal.
        emit Withdraw(owner(), amounts);
    }

    /// @inheritdoc IVault
    function setGuardianAndFeeRecipient(
        address newGuardian,
        address newFeeRecipient
    ) external override onlyOwner whenNotFinalized reserveFees {
        // Requirements: check guardian and fee recipient addresses.
        _checkGuardianAddress(newGuardian);
        _checkFeeRecipientAddress(newFeeRecipient);

        // Effects: update guardian and fee recipient addresses.
        guardian = newGuardian;
        feeRecipient = newFeeRecipient;

        // Log new guardian and fee recipient addresses.
        emit SetGuardianAndFeeRecipient(newGuardian, newFeeRecipient);
    }

    /// @inheritdoc IVault
    function setHooks(address newHooks)
        external
        override
        onlyOwner
        whenNotFinalized
        reserveFees
    {
        // Requirements: validate hooks address.
        _checkHooksAddress(newHooks);

        // Effects: decommission old hooks contract.
        if (address(hooks) != address(0)) {
            hooks.decommission();
        }

        // Effects: set new hooks address.
        hooks = IHooks(newHooks);

        // Log new hooks address.
        emit SetHooks(newHooks);
    }

    /// @inheritdoc IVault
    function execute(Operation calldata operation)
        external
        override
        onlyOwner
    {
        // Requirements: check that the target contract is not hooks.
        if (operation.target == address(hooks)) {
            revert Aera__ExecuteTargetIsHooksAddress();
        }

        uint256 prevFeeTokenBalance =
            assetRegistry.feeToken().balanceOf(address(this));

        // Interactions: execute operation.
        (bool success, bytes memory result) =
            operation.target.call{value: operation.value}(operation.data);

        // Invariants: check that the operation was successful.
        if (!success) {
            revert Aera__ExecutionFailed(result);
        }

        // Invariants: check that insolvency of fee token was not introduced or increased.
        _checkReservedFees(prevFeeTokenBalance);

        // Log that the operation was executed.
        emit Executed(owner(), operation);
    }

    /// @inheritdoc IVault
    function finalize()
        external
        override
        nonReentrant
        onlyOwner
        whenHooksSet
        whenNotFinalized
        reserveFees
    {
        // Hooks: before finalizing.
        hooks.beforeFinalize();

        // Effects: mark the vault as finalized.
        finalized = true;

        IAssetRegistry.AssetInformation[] memory assets =
            assetRegistry.assets();
        AssetValue[] memory assetAmounts = _getHoldings(assets);
        uint256 numAssetAmounts = assetAmounts.length;

        for (uint256 i = 0; i < numAssetAmounts;) {
            // Effects: transfer registered assets to owner.
            // Excludes reserved fee tokens and native token (e.g., ETH).
            assetAmounts[i].asset.safeTransfer(owner(), assetAmounts[i].value);
            unchecked {
                i++; // gas savings
            }
        }

        // Hooks: after finalizing.
        hooks.afterFinalize();

        // Log finalization.
        emit Finalized(owner(), assetAmounts);
    }

    /// @inheritdoc IVault
    function pause()
        external
        override
        onlyOwnerOrGuardian
        whenNotPaused
        whenNotFinalized
        reserveFees
    {
        // Effects: pause the vault.
        _pause();
    }

    /// @inheritdoc IVault
    function resume()
        external
        override
        onlyOwner
        whenPaused
        whenHooksSet
        whenNotFinalized
    {
        // Effects: start a new fee checkpoint.
        lastFeeCheckpoint = block.timestamp;

        // Effects: unpause the vault.
        _unpause();
    }

    /// @inheritdoc IVault
    function submit(Operation[] calldata operations)
        external
        override
        nonReentrant
        onlyGuardian
        whenNotFinalized
        whenNotPaused
        reserveFees
    {
        // Hooks: before executing operations.
        hooks.beforeSubmit(operations);

        uint256 prevFeeTokenBalance =
            assetRegistry.feeToken().balanceOf(address(this));

        uint256 numOperations = operations.length;

        Operation calldata operation;
        bool success;
        bytes memory result;
        address hooksAddress = address(hooks);

        for (uint256 i = 0; i < numOperations;) {
            operation = operations[i];

            // Requirements: validate that it doesn't transfer asset from owner.
            if (
                bytes4(operation.data[0:4]) == IERC20.transferFrom.selector
                    && abi.decode(operation.data[4:], (address)) == owner()
            ) {
                revert Aera__SubmitTransfersAssetFromOwner();
            }

            // Requirements: check that the target contract is not hooks.
            if (operation.target == hooksAddress) {
                revert Aera__SubmitTargetIsHooksAddress();
            }

            // Interactions: execute operation.
            (success, result) =
                operation.target.call{value: operation.value}(operation.data);

            // Invariants: confirm that operation succeeded.
            if (!success) {
                revert Aera__SubmissionFailed(i, result);
            }
            unchecked {
                i++; // gas savings
            }
        }

        // Invariants: check that insolvency of fee token was not introduced or increased.
        _checkReservedFees(prevFeeTokenBalance);

        // Hooks: after executing operations.
        hooks.afterSubmit(operations);

        // Log submission.
        emit Submitted(owner(), operations);
    }

    /// @inheritdoc IVault
    function claim() external override nonReentrant reserveFees {
        uint256 reservedFee = fees[msg.sender];

        // Requirements: check that there are fees to claim.
        if (reservedFee == 0) {
            revert Aera__NoClaimableFeesForCaller(msg.sender);
        }

        IERC20 feeToken = assetRegistry.feeToken();

        uint256 availableFee =
            Math.min(feeToken.balanceOf(address(this)), reservedFee);
        uint256 unavailableFee = reservedFee - availableFee;
        feeTotal -= availableFee;
        reservedFee -= availableFee;

        // Effects: update leftover fee.
        fees[msg.sender] = reservedFee;

        // Interactions: transfer fee to caller.
        feeToken.safeTransfer(msg.sender, availableFee);

        // Log the claim.
        emit Claimed(msg.sender, availableFee, unavailableFee);
    }

    /// @inheritdoc IVault
    function holdings() public view override returns (AssetValue[] memory) {
        IAssetRegistry.AssetInformation[] memory assets =
            assetRegistry.assets();

        return _getHoldings(assets);
    }

    /// @inheritdoc IVault
    function value() external view override returns (uint256 vaultValue) {
        IAssetRegistry.AssetPriceReading[] memory erc20SpotPrices =
            assetRegistry.spotPrices();
        IERC20 feeToken = assetRegistry.feeToken();

        (vaultValue,) = _value(erc20SpotPrices, feeToken);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return interfaceId == type(IVault).interfaceId
            || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc Ownable
    function renounceOwnership() public view override onlyOwner {
        revert Aera__CannotRenounceOwnership();
    }

    /// @notice Only accept ETH from the WETH contract when burning WETH tokens.
    receive() external payable {
        // Requirements: verify that the sender is WETH.
        if (msg.sender != weth) {
            revert Aera__NotWETHContract();
        }
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
    function _reserveFees() internal {
        // Requirements: check if fees are being accrued.
        if (fee == 0 || paused() || finalized) {
            return;
        }

        uint256 feeIndex = _getFeeIndex();

        // Requirements: check if fees have been accruing.
        if (feeIndex == 0) {
            return;
        }

        IERC20 feeToken = assetRegistry.feeToken();

        // Calculate vault value using oracle or backup value if oracle is reverting.
        try assetRegistry.spotPrices() returns (
            IAssetRegistry.AssetPriceReading[] memory erc20SpotPrices
        ) {
            (lastValue, lastFeeTokenPrice) = _value(erc20SpotPrices, feeToken);
        } catch {}

        // Requirements: check that fee token has a positive price.
        if (lastFeeTokenPrice == 0) {
            return;
        }

        IERC20 numeraireAsset =
            assetRegistry.assets()[assetRegistry.numeraireId()].asset;

        // Calculate new fee for current fee recipient.
        uint256 newFee = lastValue * feeIndex * fee
            * 10 ** IERC20Metadata(address(feeToken)).decimals()
            / lastFeeTokenPrice
            / 10 ** IERC20Metadata(address(numeraireAsset)).decimals();

        if (newFee == 0) {
            return;
        }

        // Move fee checkpoint only if fee is nonzero
        lastFeeCheckpoint = block.timestamp;

        // Effects: accrue fee to fee recipient and remember new fee total.
        fees[feeRecipient] += newFee;
        feeTotal += newFee;
    }

    /// @notice Get current total value of assets in vault and price of fee token.
    /// @param erc20SpotPrices Spot prices of ERC20 assets.
    /// @param feeToken Fee token address.
    /// @return vaultValue Current total value.
    /// @return feeTokenPrice Fee token price.
    function _value(
        IAssetRegistry.AssetPriceReading[] memory erc20SpotPrices,
        IERC20 feeToken
    ) internal view returns (uint256 vaultValue, uint256 feeTokenPrice) {
        IAssetRegistry.AssetInformation[] memory assets =
            assetRegistry.assets();
        AssetValue[] memory assetAmounts = _getHoldings(assets);

        (uint256[] memory spotPrices, uint256[] memory assetUnits) =
            _getSpotPricesAndUnits(assets, erc20SpotPrices);

        uint256 numAssets = assets.length;
        uint256 balance;

        for (uint256 i = 0; i < numAssets;) {
            if (assets[i].isERC4626) {
                balance = IERC4626(address(assets[i].asset)).convertToAssets(
                    assetAmounts[i].value
                );
            } else {
                balance = assetAmounts[i].value;
            }

            if (assets[i].asset == feeToken) {
                feeTokenPrice = spotPrices[i];
            }

            vaultValue += (balance * spotPrices[i]) / assetUnits[i];
            unchecked {
                i++; // gas savings
            }
        }

        uint256 numeraireUnit = assetUnits[assetRegistry.numeraireId()];

        if (numeraireUnit != ONE) {
            vaultValue = vaultValue * numeraireUnit / ONE;
        }
    }

    /// @notice Check request to withdraw.
    /// @param assets Struct details for asset information from asset registry.
    /// @param amounts Struct details for assets and amounts to withdraw.
    function _checkWithdrawRequest(
        IAssetRegistry.AssetInformation[] memory assets,
        AssetValue[] memory amounts
    ) internal view {
        uint256 numAmounts = amounts.length;

        AssetValue[] memory assetAmounts = _getHoldings(assets);

        bool isRegistered;
        AssetValue memory assetValue;
        uint256 assetIndex;

        for (uint256 i = 0; i < numAmounts;) {
            assetValue = amounts[i];
            (isRegistered, assetIndex) =
                _isAssetRegistered(assetValue.asset, assets);

            if (!isRegistered) {
                revert Aera__AssetIsNotRegistered(assetValue.asset);
            }

            for (uint256 j = 0; j < numAmounts;) {
                if (i != j && assetValue.asset == amounts[j].asset) {
                    revert Aera__AssetIsDuplicated(assetValue.asset);
                }
                unchecked {
                    j++; // gas savings
                }
            }

            if (assetAmounts[assetIndex].value < assetValue.value) {
                revert Aera__AmountExceedsAvailable(
                    assetValue.asset,
                    assetValue.value,
                    assetAmounts[assetIndex].value
                );
            }
            unchecked {
                i++; // gas savings
            }
        }
    }

    /// @notice Get spot prices and units of requested assets.
    /// @param assets Registered assets in asset registry and their information.
    /// @param erc20SpotPrices Struct details for spot prices of ERC20 assets.
    /// @return spotPrices Spot prices of assets.
    /// @return assetUnits Units of assets.
    function _getSpotPricesAndUnits(
        IAssetRegistry.AssetInformation[] memory assets,
        IAssetRegistry.AssetPriceReading[] memory erc20SpotPrices
    )
        internal
        view
        returns (uint256[] memory spotPrices, uint256[] memory assetUnits)
    {
        uint256 numAssets = assets.length;
        uint256 numERC20SpotPrices = erc20SpotPrices.length;

        spotPrices = new uint256[](numAssets);
        assetUnits = new uint256[](numAssets);

        IAssetRegistry.AssetInformation memory asset;
        address underlyingAsset;

        for (uint256 i = 0; i < numAssets;) {
            asset = assets[i];

            if (asset.isERC4626) {
                underlyingAsset = IERC4626(address(asset.asset)).asset();
                for (uint256 j = 0; j < numERC20SpotPrices;) {
                    if (underlyingAsset == address(erc20SpotPrices[j].asset)) {
                        spotPrices[i] = erc20SpotPrices[j].spotPrice;
                        assetUnits[i] =
                            10 ** IERC20Metadata(underlyingAsset).decimals();
                        break;
                    }
                    unchecked {
                        j++; // gas savings
                    }
                }
            } else {
                for (uint256 j = 0; j < numERC20SpotPrices;) {
                    if (asset.asset == erc20SpotPrices[j].asset) {
                        spotPrices[i] = erc20SpotPrices[j].spotPrice;
                        break;
                    }
                    unchecked {
                        j++; // gas savings
                    }
                }

                assetUnits[i] =
                    10 ** IERC20Metadata(address(asset.asset)).decimals();
            }
            unchecked {
                i++; // gas savings
            }
        }
    }

    /// @notice Get total amount of assets in vault module.
    /// @param assets Struct details for registered assets in asset registry.
    /// @return assetAmounts Amount of assets.
    function _getHoldings(IAssetRegistry.AssetInformation[] memory assets)
        internal
        view
        returns (AssetValue[] memory assetAmounts)
    {
        uint256 numAssets = assets.length;

        IERC20 feeToken = assetRegistry.feeToken();
        assetAmounts = new AssetValue[](numAssets);
        IAssetRegistry.AssetInformation memory asset;

        for (uint256 i = 0; i < numAssets;) {
            asset = assets[i];
            assetAmounts[i] = AssetValue({
                asset: asset.asset,
                value: asset.asset.balanceOf(address(this))
            });

            if (asset.asset == feeToken) {
                if (assetAmounts[i].value > feeTotal) {
                    assetAmounts[i].value -= feeTotal;
                } else {
                    assetAmounts[i].value = 0;
                }
            }
            unchecked {
                i++; //gas savings
            }
        }
    }

    /// @notice Check if balance of fee becomes insolvent or becomes more insolvent.
    /// @param prevFeeTokenBalance Balance of fee token before action.
    function _checkReservedFees(uint256 prevFeeTokenBalance) internal view {
        uint256 feeTokenBalance =
            assetRegistry.feeToken().balanceOf(address(this));

        if (
            feeTokenBalance < feeTotal && feeTokenBalance < prevFeeTokenBalance
        ) {
            revert Aera__CannotUseReservedFees();
        }
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

    /// @notice Check if the address can be a fee recipient.
    /// @param newFeeRecipient Address to check.
    function _checkFeeRecipientAddress(address newFeeRecipient)
        internal
        view
    {
        if (newFeeRecipient == address(0)) {
            revert Aera__FeeRecipientIsZeroAddress();
        }
        if (newFeeRecipient == owner()) {
            revert Aera__FeeRecipientIsOwner();
        }
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
        if (IAssetRegistry(newAssetRegistry).vault() != address(this)) {
            revert Aera__AssetRegistryHasInvalidVault();
        }
    }

    /// @notice Check if the address can be a hooks contract.
    /// @param newHooks Address to check.
    function _checkHooksAddress(address newHooks) internal view {
        if (newHooks == address(0)) {
            revert Aera__HooksIsZeroAddress();
        }
        if (
            !ERC165Checker.supportsInterface(newHooks, type(IHooks).interfaceId)
        ) {
            revert Aera__HooksIsNotValid(newHooks);
        }
        if (IHooks(newHooks).vault() != address(this)) {
            revert Aera__HooksHasInvalidVault();
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
