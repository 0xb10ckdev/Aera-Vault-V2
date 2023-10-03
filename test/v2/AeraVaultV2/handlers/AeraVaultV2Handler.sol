// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {TestBase} from "test/utils/TestBase.sol";
import {ISwapRouter} from
    "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/IERC4626.sol";
import "src/v2/AeraVaultAssetRegistry.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/AeraVaultHooks.sol";
import "src/v2/interfaces/IAssetRegistry.sol";

contract AeraVaultV2Handler is TestBase {
    address internal constant _UNISWAP_ROUTER =
        0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address internal constant _BALANCER_VAULT =
        0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    bytes32 internal constant _BALANCER_USDC_WETH_POOL =
        0x96646936b91d6b9d7d0c47c496afbf3d6ec7b6f8000200000000000000000019;
    bytes32 internal constant _BALANCER_WBTC_WETH_POOL =
        0xa6f548df93de924d73be7d25dc02554c6bd66db500020000000000000000000e;
    bytes4 internal constant _TRANSFER_SELECTOR = IERC20.transfer.selector;
    bytes4 internal constant _APPROVE_SELECTOR = IERC20.approve.selector;
    bytes4 internal constant _DEPOSIT_SELECTOR = IERC4626.deposit.selector;
    bytes4 internal constant _EXACT_INPUT_SINGLE_SELECTOR =
        ISwapRouter.exactInputSingle.selector;
    bytes4 internal constant _BALANCER_SWAP_SELECTOR =
        IBalancerVault.swap.selector;

    AeraVaultV2 public vault;
    AeraVaultV2 public vaultWithHooksMock;
    AeraVaultHooks public hooks;
    AeraVaultAssetRegistry public assetRegistry;
    IERC20[] public erc20Assets;
    IERC4626[] public yieldAssets;
    uint256[] public oraclePrices;
    uint256 public numERC20Assets;
    uint256 public numYieldAssets;
    uint256 public numeraireUnit;

    uint256 public beforeValue;
    bool public vaultValueChanged;
    bool public feeTokenBalanceReduced;

    constructor(
        AeraVaultV2 vault_,
        AeraVaultV2 vaultWithHooksMock_,
        AeraVaultHooks hooks_,
        AeraVaultAssetRegistry assetRegistry_,
        IERC20[] memory erc20Assets_,
        IERC4626[] memory yieldAssets_,
        uint256[] memory oraclePrices_
    ) {
        vault = vault_;
        vaultWithHooksMock = vaultWithHooksMock_;
        hooks = hooks_;
        assetRegistry = assetRegistry_;
        erc20Assets = erc20Assets_;
        yieldAssets = yieldAssets_;
        oraclePrices = oraclePrices_;
        numeraireUnit = 10
            ** IERC20Metadata(address(assetRegistry.numeraireToken())).decimals();
        numERC20Assets = erc20Assets_.length;
        numYieldAssets = yieldAssets_.length;

        beforeValue = vault.value();
    }

    function runDeposit(uint256[50] memory amounts) public {
        IAssetRegistry.AssetInformation[] memory assets =
            vault.assetRegistry().assets();
        AssetValue[] memory depositAmounts = new AssetValue[](assets.length);

        vm.startPrank(vault.owner());
        for (uint256 i = 0; i < assets.length; i++) {
            IERC20 asset = assets[i].asset;
            amounts[i] %= 1000e30;

            deal(address(asset), vault.owner(), amounts[i] * 2);
            asset.approve(address(vault), amounts[i]);
            asset.approve(address(vaultWithHooksMock), amounts[i]);

            depositAmounts[i] = AssetValue({asset: asset, value: amounts[i]});

            _checkVaultValueStatus(address(asset), oraclePrices[i], amounts[i]);
        }

        vault.deposit(depositAmounts);
        vaultWithHooksMock.deposit(depositAmounts);
        vm.stopPrank();
    }

    function runWithdraw(uint256[50] memory amounts) public {
        IAssetRegistry.AssetInformation[] memory assets =
            vault.assetRegistry().assets();
        AssetValue[] memory withdrawAmounts = new AssetValue[](assets.length);

        for (uint256 i = 0; i < assets.length; i++) {
            IERC20 asset = assets[i].asset;
            amounts[i] %= asset.balanceOf(address(vault));

            withdrawAmounts[i] = AssetValue({asset: asset, value: amounts[i]});

            _checkVaultValueStatus(address(asset), oraclePrices[i], amounts[i]);
        }

        vm.startPrank(vault.owner());
        vault.withdraw(withdrawAmounts);
        vaultWithHooksMock.withdraw(withdrawAmounts);
        vm.stopPrank();
    }

    function finalize() public {
        vm.startPrank(vault.owner());
        vault.finalize();
        vaultWithHooksMock.finalize();
        vm.stopPrank();

        vaultValueChanged = true;
    }

    function runExecute(
        uint256 assetIndex,
        uint256 amount,
        uint256 skipTimestamp
    ) public {
        IAssetRegistry.AssetInformation[] memory assets =
            vault.assetRegistry().assets();
        assetIndex %= assets.length;
        address asset = address(assets[assetIndex].asset);
        amount %= IERC20(asset).balanceOf(address(vault));

        skip(skipTimestamp % 10000);

        Operation memory operation = Operation({
            target: asset,
            value: 0,
            data: abi.encodeWithSelector(_TRANSFER_SELECTOR, address(this), amount)
        });

        _checkVaultValueStatus(asset, oraclePrices[assetIndex], amount);

        vm.startPrank(vault.owner());
        vault.execute(operation);
        vaultWithHooksMock.execute(operation);
        vm.stopPrank();
    }

    function runSubmit(
        uint256[10] memory amounts,
        uint256 skipTimestamp
    ) public {
        IAssetRegistry.AssetInformation[] memory assets =
            vault.assetRegistry().assets();

        skip(skipTimestamp % 10000);

        Operation[] memory operations = new Operation[](assets.length);

        vm.startPrank(hooks.owner());
        for (uint256 i = 0; i < assets.length; i++) {
            address asset = address(assets[i].asset);
            amounts[i] %= assets[i].asset.balanceOf(address(vault));

            operations[i] = Operation({
                target: asset,
                value: 0,
                data: abi.encodeWithSelector(
                    _TRANSFER_SELECTOR, address(uint160(i + 1)), amounts[i]
                    )
            });

            _addTargetSighash(asset, _TRANSFER_SELECTOR);

            _checkVaultValueStatus(asset, oraclePrices[i], amounts[i]);
        }
        vm.stopPrank();

        _submit(operations);
    }

    function runSubmitDepositToYield(
        uint256[3] memory tokenIndex,
        uint256[3] memory amounts,
        uint256 skipTimestamp
    ) public {
        vm.startPrank(hooks.owner());

        skip(skipTimestamp % 10000);

        Operation[] memory operations = new Operation[](tokenIndex.length * 2);

        for (uint256 i = 0; i < tokenIndex.length; i++) {
            uint256 index = tokenIndex[i] % numYieldAssets;
            address asset = address(yieldAssets[index]);
            address underlyingAsset = yieldAssets[index].asset();

            amounts[i] %= IERC20(underlyingAsset).balanceOf(address(vault));

            operations[i * 2] = Operation({
                target: underlyingAsset,
                value: 0,
                data: abi.encodeWithSelector(_APPROVE_SELECTOR, asset, amounts[i])
            });
            operations[i * 2 + 1] = Operation({
                target: asset,
                value: 0,
                data: abi.encodeWithSelector(
                    _DEPOSIT_SELECTOR, amounts[i], address(vault)
                    )
            });

            _addTargetSighash(underlyingAsset, _APPROVE_SELECTOR);
            _addTargetSighash(asset, _DEPOSIT_SELECTOR);

            _checkVaultValueStatus(asset, oraclePrices[index], amounts[i]);
        }
        vm.stopPrank();

        _submit(operations);
    }

    function runSubmitSwapViaUniswap(
        uint256[2][3] memory tokenIndex,
        uint256[3] memory amounts,
        uint256 skipTimestamp
    ) public {
        vm.startPrank(hooks.owner());

        _addTargetSighash(_UNISWAP_ROUTER, _EXACT_INPUT_SINGLE_SELECTOR);

        skip(skipTimestamp % 10000);

        Operation[] memory operations = new Operation[](tokenIndex.length * 2);

        for (uint256 i = 0; i < tokenIndex.length; i++) {
            (address tokenIn, address tokenOut) =
                _getTokenInTokenOut(tokenIndex[i]);

            amounts[i] %= IERC20(tokenIn).balanceOf(address(vault));

            operations[i * 2] = Operation({
                target: tokenIn,
                value: 0,
                data: abi.encodeWithSelector(
                    _APPROVE_SELECTOR, _UNISWAP_ROUTER, amounts[i]
                    )
            });
            operations[i * 2 + 1] = Operation({
                target: _UNISWAP_ROUTER,
                value: 0,
                data: abi.encodeWithSelector(
                    _EXACT_INPUT_SINGLE_SELECTOR,
                    ISwapRouter.ExactInputSingleParams({
                        tokenIn: tokenIn,
                        tokenOut: tokenOut,
                        fee: 500,
                        recipient: address(vault),
                        deadline: block.timestamp,
                        amountIn: amounts[i],
                        amountOutMinimum: 0,
                        sqrtPriceLimitX96: 0
                    })
                    )
            });

            _addTargetSighash(tokenIn, _APPROVE_SELECTOR);

            _checkVaultValueStatus(
                tokenIn,
                oraclePrices[tokenIndex[i][0] % numERC20Assets],
                amounts[i]
            );
        }
        vm.stopPrank();

        _submit(operations);
    }

    function runSubmitSwapViaBalancer(
        uint256[2][3] memory tokenIndex,
        uint256[3] memory amounts,
        uint256 skipTimestamp
    ) public {
        vm.startPrank(hooks.owner());

        _addTargetSighash(_BALANCER_VAULT, _BALANCER_SWAP_SELECTOR);

        skip(skipTimestamp % 10000);

        Operation[] memory operations = new Operation[](tokenIndex.length * 2);

        for (uint256 i = 0; i < tokenIndex.length; i++) {
            (address tokenIn, address tokenOut) =
                _getTokenInTokenOut(tokenIndex[i]);

            amounts[i] %= IERC20(tokenIn).balanceOf(address(vault));

            bytes32 poolId;
            if (tokenIn == _WETH_ADDRESS || tokenOut == _WETH_ADDRESS) {
                if (tokenIn == _USDC_ADDRESS || tokenOut == _USDC_ADDRESS) {
                    poolId = _BALANCER_USDC_WETH_POOL;
                } else if (
                    tokenIn == _WBTC_ADDRESS || tokenOut == _WBTC_ADDRESS
                ) {
                    poolId = _BALANCER_WBTC_WETH_POOL;
                }
            }
            if (poolId == bytes32(0)) {
                return;
            }

            operations[i * 2] = Operation({
                target: tokenIn,
                value: 0,
                data: abi.encodeWithSelector(
                    _APPROVE_SELECTOR, _BALANCER_VAULT, amounts[i]
                    )
            });
            operations[i * 2 + 1] = Operation({
                target: _BALANCER_VAULT,
                value: 0,
                data: abi.encodeWithSelector(
                    _BALANCER_SWAP_SELECTOR,
                    IBalancerVault.SingleSwap({
                        poolId: poolId,
                        kind: 0, // GIVEN_IN
                        assetIn: tokenIn,
                        assetOut: tokenOut,
                        amount: amounts[i],
                        userData: ""
                    }),
                    IBalancerVault.FundManagement({
                        sender: address(vault),
                        fromInternalBalance: false,
                        recipient: address(vault),
                        toInternalBalance: false
                    }),
                    0,
                    block.timestamp
                    )
            });

            _addTargetSighash(tokenIn, _APPROVE_SELECTOR);
        }
        vm.stopPrank();

        for (uint256 i = 0; i < tokenIndex.length; i++) {
            uint256 tokenInIndex = tokenIndex[i][0] % numERC20Assets;
            _checkVaultValueStatus(
                address(erc20Assets[tokenInIndex]),
                oraclePrices[tokenInIndex],
                amounts[i]
            );
        }

        _submit(operations);
    }

    function _submit(Operation[] memory operations) internal {
        uint256 prevFeeTokenBalance =
            assetRegistry.feeToken().balanceOf(address(vault));

        vm.startPrank(vault.guardian());
        vault.submit(operations);
        vaultWithHooksMock.submit(operations);
        vm.stopPrank();

        uint256 feeTokenBalance =
            assetRegistry.feeToken().balanceOf(address(vault));
        if (
            feeTokenBalance < vault.feeTotal()
                && feeTokenBalance < prevFeeTokenBalance
        ) {
            feeTokenBalanceReduced = true;
        }
    }

    function _addTargetSighash(address target, bytes4 selector) internal {
        if (!hooks.targetSighashAllowed(target, selector)) {
            hooks.addTargetSighash(target, selector);
        }
    }

    function _getTokenInTokenOut(uint256[2] memory tokenIndex)
        internal
        view
        returns (address tokenIn, address tokenOut)
    {
        uint256 tokenInIndex = tokenIndex[0] % numERC20Assets;
        uint256 tokenOutIndex = tokenIndex[1] % numERC20Assets;
        if (tokenInIndex == tokenOutIndex) {
            tokenOutIndex = (tokenOutIndex + 1) % numERC20Assets;
        }

        tokenIn = address(erc20Assets[tokenInIndex]);
        tokenOut = address(erc20Assets[tokenOutIndex]);
    }

    function _checkVaultValueStatus(
        address asset,
        uint256 price,
        uint256 amount
    ) internal {
        uint256 assetDecimals = IERC20Metadata(asset).decimals();
        if (amount * price * numeraireUnit / _ONE / 10 ** assetDecimals > 0) {
            vaultValueChanged = true;
        }
    }
}

interface IBalancerVault {
    struct SingleSwap {
        bytes32 poolId;
        uint8 kind;
        address assetIn;
        address assetOut;
        uint256 amount;
        bytes userData;
    }

    struct FundManagement {
        address sender;
        bool fromInternalBalance;
        address recipient;
        bool toInternalBalance;
    }

    function swap(
        SingleSwap memory singleSwap,
        FundManagement memory funds,
        uint256 limit,
        uint256 deadline
    ) external payable returns (uint256);
}
