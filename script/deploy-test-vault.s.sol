// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "src/v2/interfaces/IAeraVaultV2Factory.sol";
import "src/v2/interfaces/IAssetRegistry.sol";
import "src/v2/interfaces/IHooks.sol";
import "src/v2/AeraVaultHooks.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/Types.sol";
import "src/v2/AeraVaultAssetRegistry.sol";
import "src/v2/TargetSighashLib.sol";
import "src/v2/dependencies/openzeppelin/IERC20.sol";

contract DeployTestVault is Script {
    using TargetSighashLib for TargetSighash;

    address factoryAddressPolygon = 0x94491d7357097Bd55272bEeBF371b8d74125c233;
    address guardianAddress = 0xba1a7CEd3090D6235d454bfe52e53B215AB23421;
    address feeRecipientAddress = 0xba1a7CEd3090D6235d454bfe52e53B215AB23421;
    address swapRouterAddress = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    uint256 fee = 0;
    uint256 maxDailyExecutionLoss = 1e18;
    IERC20 usdc = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    IERC20 weth = IERC20(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);
    address wethOracleAddress = 0xF9680D99D6C9589e2a93a78A04A279e509205945;

    event SetHooks(address hooks);

    TargetSighash[] targetSighashAllowlist = [
        TargetSighashLib.toTargetSighash(address(usdc), IERC20.approve.selector),
        TargetSighashLib.toTargetSighash(address(usdc), IERC20.transfer.selector),
        TargetSighashLib.toTargetSighash(address(weth), IERC20.approve.selector),
        TargetSighashLib.toTargetSighash(address(weth), IERC20.transfer.selector),
        TargetSighashLib.toTargetSighash(
            swapRouterAddress, ISwapRouter.exactInput.selector
        ),
        TargetSighashLib.toTargetSighash(
            swapRouterAddress, ISwapRouter.exactInputSingle.selector
        ),
        TargetSighashLib.toTargetSighash(
            swapRouterAddress, ISwapRouter.exactOutput.selector
        ),
        TargetSighashLib.toTargetSighash(
            swapRouterAddress, ISwapRouter.exactOutputSingle.selector
        )
    ];

    function run() external {
        address assetRegistryAddress = deployAssetRegistry();

        IAeraVaultV2Factory aeraVaultV2Factory =
            IAeraVaultV2Factory(factoryAddressPolygon);
        address vaultAddress = 0x14F19E4a7364c4e6da55f2B08D65323e95A71915;
        AeraVaultV2 vault = AeraVaultV2(vaultAddress);
        vm.startBroadcast();
        aeraVaultV2Factory.create(
            assetRegistryAddress,
            guardianAddress,
            feeRecipientAddress,
            fee,
            maxDailyExecutionLoss,
            targetSighashAllowlist
        );
        // Currently Factory.create deploys and sets hooks, but won't in the future
        // AeraVaultHooks hooks =
        // new AeraVaultHooks(address(vault), maxDailyExecutionLoss, targetSighashAllowlist);
        // vault.setHooks(address(hooks));
        vm.stopBroadcast();
    }

    function deployAssetRegistry() public returns (address) {
        IAssetRegistry.AssetInformation[] memory assets =
            new IAssetRegistry.AssetInformation[](2);
        assets[0] = IAssetRegistry.AssetInformation({
            asset: usdc,
            isERC4626: false,
            oracle: AggregatorV2V3Interface(address(0))
        });

        assets[1] = IAssetRegistry.AssetInformation({
            asset: weth,
            isERC4626: false,
            oracle: AggregatorV2V3Interface(wethOracleAddress)
        });
        uint256 numeraireId = 0;
        vm.startBroadcast();
        AeraVaultAssetRegistry registry =
            new AeraVaultAssetRegistry(assets, numeraireId, usdc);
        vm.stopBroadcast();
        return address(registry);
    }
}
