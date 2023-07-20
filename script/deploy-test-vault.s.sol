// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "src/v2/interfaces/IAeraVaultV2Factory.sol";
import "src/v2/interfaces/IAssetRegistry.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/Types.sol";
import "src/v2/AeraVaultAssetRegistry.sol";
import "src/v2/TargetSighashLib.sol";
import "src/v2/dependencies/openzeppelin/IERC20.sol";

contract DeployTestVault is Script {
    using TargetSighashLib for TargetSighash;
    // TODO add live deployed factory address

    address factoryAddressPolygon = 0x94491d7357097Bd55272bEeBF371b8d74125c233;
    address guardianAddress = 0xba1a7CEd3090D6235d454bfe52e53B215AB23421;
    address feeRecipientAddress = 0xba1a7CEd3090D6235d454bfe52e53B215AB23421;
    address swapRouterAddress = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    uint256 fee = 0;
    uint256 maxDailyExecutionLoss = 100;
    IERC20 usdc = IERC20(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174);
    IERC20 weth = IERC20(0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619);
    address wethOracleAddress = 0xF9680D99D6C9589e2a93a78A04A279e509205945;

    bytes4 internal constant _APPROVE_SELECTOR =
        bytes4(keccak256("approve(address,uint256)"));
    bytes4 internal constant _INCREASE_ALLOWANCE_SELECTOR =
        bytes4(keccak256("increaseAllowance(address,uint256)"));
    bytes4 internal constant _TRANSFER_SELECTOR =
        bytes4(keccak256("transfer(address,uint256)"));
    bytes4 internal constant _EXACT_INPUT_SELECTOR = bytes4(
        keccak256("exactInput((bytes,address,uint256,uint256,uint256))")
    );
    bytes4 internal constant _EXACT_INPUT_SINGLE_SELECTOR = bytes4(
        keccak256(
            "exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))"
        )
    );
    bytes4 internal constant _EXACT_OUTPUT_SELECTOR = bytes4(
        keccak256("exactOutput((bytes,address,uint256,uint256,uint256))")
    );
    bytes4 internal constant _EXACT_OUTPUT_SINGLE_SELECTOR = bytes4(
        keccak256(
            "exactOutputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))"
        )
    );

    TargetSighash[] targetSighashAllowList = [
        TargetSighashLib.toTargetSighash(address(usdc), _APPROVE_SELECTOR),
        TargetSighashLib.toTargetSighash(address(usdc), _TRANSFER_SELECTOR),
        TargetSighashLib.toTargetSighash(address(weth), _APPROVE_SELECTOR),
        TargetSighashLib.toTargetSighash(address(weth), _TRANSFER_SELECTOR),
        TargetSighashLib.toTargetSighash(swapRouterAddress, _EXACT_INPUT_SELECTOR),
        TargetSighashLib.toTargetSighash(
            swapRouterAddress, _EXACT_INPUT_SINGLE_SELECTOR
        ),
        TargetSighashLib.toTargetSighash(swapRouterAddress, _EXACT_OUTPUT_SELECTOR),
        TargetSighashLib.toTargetSighash(
            swapRouterAddress, _EXACT_OUTPUT_SINGLE_SELECTOR
        )
    ];

    function run() external {
        address assetRegistryAddress = deployAssetRegistry();

        IAeraVaultV2Factory aeraVaultV2Factory =
            IAeraVaultV2Factory(factoryAddressPolygon);
        vm.startBroadcast();
        aeraVaultV2Factory.create(
            assetRegistryAddress,
            guardianAddress,
            feeRecipientAddress,
            fee,
            maxDailyExecutionLoss,
            targetSighashAllowList
        );
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
