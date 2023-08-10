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
import "./interfaces/IHooks.sol";
import "./interfaces/ICustody.sol";
import {ONE} from "./Constants.sol";

/// @title Aera Vault V2 Custody contract.
contract AeraVaultV2 is
    ICustody,
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

    /// @notice The address of asset registry.
    IAssetRegistry public immutable assetRegistry;

    /// STORAGE ///

    /// @notice Describes vault purpose and modelling assumptions for
    ///         differentiating between vaults.
    /// @dev string cannot be immutable bytecode but only set in constructor
    string public description;

    /// @notice The address of hooks module.
    IHooks public hooks;

    /// @notice The address of guardian.
    address public guardian;

    /// @notice The address of management fee recipient.
    address public feeRecipient;

    /// @notice Indicates that the Vault has been finalized.
    bool public finalized;

    /// @notice Last total value of assets in vault.
    uint256 public lastValue;

    /// @notice Last spot price of fee token.
    uint256 public lastFeeTokenPrice;

    /// @notice Fee earned amount for each guardian.
    mapping(address => uint256) public fees;

    /// @notice Total fee earned amount.
    uint256 public feeTotal;

    /// @notice Last timestamp where fee index was reserved.
    uint256 public lastFeeCheckpoint = type(uint256).max;

    /// MODIFIERS ///

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

    /// FUNCTIONS ///

    /// @notice Initialize the custody contract by providing references to
    ///         asset registry, guardian and other parameters.
    /// @param owner_ The address of initial owner.
    /// @param assetRegistry_ The address of asset registry.
    /// @param guardian_ The address of guardian.
    /// @param feeRecipient_ The address of fee recipient.
    /// @param fee_ Guardian fee per second in 18 decimal fixed point format.
    constructor(
        address owner_,
        address assetRegistry_,
        address guardian_,
        address feeRecipient_,
        uint256 fee_,
        string memory description_
    ) {
        _checkAssetRegistryAddress(assetRegistry_);
        _checkGuardianAddress(guardian_);
        _checkFeeRecipientAddress(feeRecipient_);

        if (fee_ > _MAX_FEE) {
            revert Aera__FeeIsAboveMax(fee_, _MAX_FEE);
        }
        if (bytes(description_).length == 0) {
            revert Aera__DescriptionIsEmpty();
        }

        assetRegistry = IAssetRegistry(assetRegistry_);
        guardian = guardian_;
        feeRecipient = feeRecipient_;
        fee = fee_;
        description = description_;
        lastFeeCheckpoint = block.timestamp;

        _transferOwnership(owner_);
        _pause();

        emit SetAssetRegistry(assetRegistry_);
        emit SetGuardianAndFeeRecipient(guardian_, feeRecipient_);
    }

    /// @inheritdoc ICustody
    function deposit(AssetValue[] calldata amounts)
        external
        override
        nonReentrant
        onlyOwner
        whenHooksSet
        whenNotFinalized
    {
        _reserveFees();

        hooks.beforeDeposit(amounts);

        IAssetRegistry.AssetInformation[] memory assets =
            assetRegistry.assets();

        uint256 numAmounts = amounts.length;
        AssetValue memory assetValue;
        bool isRegistered;

        for (uint256 i = 0; i < numAmounts; i++) {
            assetValue = amounts[i];
            (isRegistered,) = _isAssetRegistered(assetValue.asset, assets);

            if (!isRegistered) {
                revert Aera__AssetIsNotRegistered(assetValue.asset);
            }

            for (uint256 j = 0; j < numAmounts; j++) {
                if (i != j && assetValue.asset == amounts[j].asset) {
                    revert Aera__AssetIsDuplicated(assetValue.asset);
                }
            }

            assetValue.asset.safeTransferFrom(
                owner(), address(this), assetValue.value
            );
        }

        hooks.afterDeposit(amounts);

        emit Deposit(owner(), amounts);
    }

    /// @inheritdoc ICustody
    function withdraw(AssetValue[] calldata amounts)
        external
        override
        nonReentrant
        onlyOwner
        whenHooksSet
        whenNotFinalized
    {
        _reserveFees();

        hooks.beforeWithdraw(amounts);

        IAssetRegistry.AssetInformation[] memory assets =
            assetRegistry.assets();

        _checkWithdrawRequest(assets, amounts);

        uint256 numAmounts = amounts.length;
        AssetValue memory assetValue;

        for (uint256 i = 0; i < numAmounts; i++) {
            assetValue = amounts[i];

            if (assetValue.value == 0) {
                continue;
            }

            assetValue.asset.safeTransfer(owner(), assetValue.value);
        }

        hooks.afterWithdraw(amounts);

        emit Withdraw(owner(), amounts);
    }

    /// @inheritdoc ICustody
    function setGuardianAndFeeRecipient(
        address newGuardian,
        address newFeeRecipient
    ) external override onlyOwner whenNotFinalized {
        _checkGuardianAddress(newGuardian);
        _checkFeeRecipientAddress(newFeeRecipient);

        _reserveFees();

        guardian = newGuardian;
        feeRecipient = newFeeRecipient;

        emit SetGuardianAndFeeRecipient(newGuardian, newFeeRecipient);
    }

    /// @inheritdoc ICustody
    function setHooks(address newHooks)
        external
        override
        onlyOwner
        whenNotFinalized
    {
        _checkHooksAddress(newHooks);

        _reserveFees();

        hooks = IHooks(newHooks);

        emit SetHooks(newHooks);
    }

    /// @inheritdoc ICustody
    function execute(Operation calldata operation)
        external
        override
        onlyOwner
    {
        if (operation.target == address(hooks)) {
            revert Aera__ExecuteTargetIsHooksAddress();
        }

        _reserveFees();

        uint256 prevFeeTokenBalance =
            assetRegistry.feeToken().balanceOf(address(this));

        (bool success, bytes memory result) =
            operation.target.call{value: operation.value}(operation.data);

        if (!success) {
            revert Aera__ExecutionFailed(result);
        }

        _checkReservedFees(prevFeeTokenBalance);

        emit Executed(owner(), operation);
    }

    /// @inheritdoc ICustody
    function finalize()
        external
        override
        nonReentrant
        onlyOwner
        whenHooksSet
        whenNotFinalized
    {
        _reserveFees();

        hooks.beforeFinalize();

        finalized = true;

        IAssetRegistry.AssetInformation[] memory assets =
            assetRegistry.assets();
        AssetValue[] memory assetAmounts = _getHoldings(assets);
        uint256 numAssetAmounts = assetAmounts.length;

        for (uint256 i = 0; i < numAssetAmounts; i++) {
            assetAmounts[i].asset.safeTransfer(owner(), assetAmounts[i].value);
        }

        hooks.afterFinalize();

        emit Finalized(owner(), assetAmounts);
    }

    /// @inheritdoc ICustody
    function pause()
        external
        override
        onlyOwner
        whenNotPaused
        whenNotFinalized
    {
        _reserveFees();

        _pause();
    }

    /// @inheritdoc ICustody
    function resume()
        external
        override
        onlyOwner
        whenPaused
        whenHooksSet
        whenNotFinalized
    {
        lastFeeCheckpoint = block.timestamp;

        _unpause();
    }

    /// @inheritdoc ICustody
    function submit(Operation[] calldata operations)
        external
        override
        nonReentrant
        onlyGuardian
        whenNotFinalized
        whenNotPaused
    {
        _reserveFees();

        hooks.beforeSubmit(operations);

        uint256 prevFeeTokenBalance =
            assetRegistry.feeToken().balanceOf(address(this));

        uint256 numOperations = operations.length;

        Operation memory operation;
        bool success;
        bytes memory result;
        address hooksAddress = address(hooks);

        for (uint256 i = 0; i < numOperations;) {
            operation = operations[i];

            if (operation.target == hooksAddress) {
                revert Aera__SubmitTargetIsHooksAddress();
            }

            (success, result) =
                operation.target.call{value: operation.value}(operation.data);

            if (!success) {
                revert Aera__SubmissionFailed(i, result);
            }
            unchecked {
                i++; // gas savings
            }
        }

        _checkReservedFees(prevFeeTokenBalance);

        hooks.afterSubmit(operations);

        emit Submitted(owner(), operations);
    }

    /// @inheritdoc ICustody
    function claim() external override nonReentrant {
        _reserveFees();

        uint256 reservedFee = fees[msg.sender];

        if (reservedFee == 0) {
            revert Aera__NoAvailableFeeForCaller(msg.sender);
        }

        IERC20 feeToken = assetRegistry.feeToken();

        uint256 availableFee =
            Math.min(feeToken.balanceOf(address(this)), reservedFee);
        uint256 unavailableFee = reservedFee - availableFee;
        feeTotal -= availableFee;
        reservedFee -= availableFee;

        fees[msg.sender] = reservedFee;

        feeToken.safeTransfer(msg.sender, availableFee);

        emit Claimed(msg.sender, availableFee, unavailableFee);
    }

    /// @inheritdoc ICustody
    function holdings() public view override returns (AssetValue[] memory) {
        IAssetRegistry.AssetInformation[] memory assets =
            assetRegistry.assets();

        return _getHoldings(assets);
    }

    /// @inheritdoc ICustody
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
        return interfaceId == type(ICustody).interfaceId
            || super.supportsInterface(interfaceId);
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
        if (fee == 0 || paused() || finalized) {
            return;
        }

        uint256 feeIndex = _getFeeIndex();

        if (feeIndex == 0) {
            return;
        }

        lastFeeCheckpoint = block.timestamp;

        IERC20 feeToken = assetRegistry.feeToken();

        try assetRegistry.spotPrices() returns (
            IAssetRegistry.AssetPriceReading[] memory erc20SpotPrices
        ) {
            (lastValue, lastFeeTokenPrice) = _value(erc20SpotPrices, feeToken);
        } catch {}

        if (lastFeeTokenPrice == 0) {
            return;
        }

        uint256 newFee = (
            ((lastValue * feeIndex * fee) / ONE)
                * 10 ** IERC20Metadata(address(feeToken)).decimals()
        ) / lastFeeTokenPrice;

        fees[feeRecipient] += newFee;
        feeTotal += newFee;
    }

    /// @notice Get current total value of assets in vault and price of fee token.
    /// @param erc20SpotPrices Struct details for spot prices of ERC20 assets.
    /// @param feeToken Address of fee token.
    /// @return vaultValue Current total value.
    /// @return feeTokenPrice Price of fee token.
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

        for (uint256 i = 0; i < numAssets; i++) {
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

        for (uint256 i = 0; i < numAmounts; i++) {
            assetValue = amounts[i];
            (isRegistered, assetIndex) =
                _isAssetRegistered(assetValue.asset, assets);

            if (!isRegistered) {
                revert Aera__AssetIsNotRegistered(assetValue.asset);
            }

            for (uint256 j = 0; j < numAmounts; j++) {
                if (i != j && assetValue.asset == amounts[j].asset) {
                    revert Aera__AssetIsDuplicated(assetValue.asset);
                }
            }

            if (assetAmounts[assetIndex].value < assetValue.value) {
                revert Aera__AmountExceedsAvailable(
                    assetValue.asset,
                    assetValue.value,
                    assetAmounts[assetIndex].value
                );
            }
        }
    }

    /// @notice Get spot prices and units of requested assets.
    /// @param assets Struct details for registered assets in asset registry.
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

        for (uint256 i = 0; i < numAssets; i++) {
            asset = assets[i];

            if (asset.isERC4626) {
                underlyingAsset = IERC4626(address(asset.asset)).asset();
                for (uint256 j = 0; j < numERC20SpotPrices; j++) {
                    if (underlyingAsset == address(erc20SpotPrices[j].asset)) {
                        spotPrices[i] = erc20SpotPrices[j].spotPrice;
                        assetUnits[i] =
                            10 ** IERC20Metadata(underlyingAsset).decimals();
                        break;
                    }
                }
            } else {
                for (uint256 j = 0; j < numERC20SpotPrices; j++) {
                    if (asset.asset == erc20SpotPrices[j].asset) {
                        spotPrices[i] = erc20SpotPrices[j].spotPrice;
                        break;
                    }
                }

                assetUnits[i] =
                    10 ** IERC20Metadata(address(asset.asset)).decimals();
            }
        }
    }

    /// @notice Get total amount of assets in custody module.
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

        for (uint256 i = 0; i < numAssets; i++) {
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
        }
    }

    /// @notice Check if balance of fee token gets worse.
    /// @param prevFeeTokenBalance Balance of fee token before action.
    function _checkReservedFees(uint256 prevFeeTokenBalance) internal view {
        uint256 feeTokenBalance =
            assetRegistry.feeToken().balanceOf(address(this));

        if (
            feeTokenBalance < feeTotal && feeTokenBalance < prevFeeTokenBalance
        ) {
            revert Aera__CanNotUseReservedFees();
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
