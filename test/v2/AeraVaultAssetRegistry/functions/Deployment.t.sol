// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAssetRegistry.sol";

contract DeploymentTest is TestBaseAssetRegistry {
    function setUp() public override {
        _createAssets(4, 2);

        feeToken = assets[numeraireId].asset;
    }

    function test_assetRegistryDeployment_fail_whenFeeTokenIsNotRegistered()
        public
    {
        feeToken =
            IERC20(address(new ERC20Mock("Fee Token", "FEE_TOKEN", 18, 1e30)));

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__FeeTokenIsNotRegistered.selector,
                feeToken
            )
        );
        new AeraVaultAssetRegistry(assets, numeraireId, feeToken);
    }

    function test_assetRegistryDeployment_fail_whenNumeraireIndexIsTooHigh()
        public
    {
        uint256 invalidNumeraire = numAssets + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__NumeraireIndexTooHigh.selector,
                numAssets,
                invalidNumeraire
            )
        );
        new AeraVaultAssetRegistry(assets, invalidNumeraire, feeToken);
    }

    function test_assetRegistryDeployment_fail_whenAssetOrderIsIncorrect()
        public
    {
        IAssetRegistry.AssetInformation memory temp = assets[0];
        assets[0] = assets[1];
        assets[1] = temp;

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__AssetOrderIsIncorrect.selector, 1
            )
        );
        new AeraVaultAssetRegistry(assets, numeraireId, feeToken);
    }

    function test_assetRegistryDeployment_fail_whenNumeraireOracleIsNotZeroAddress(
    ) public {
        assets[numeraireId].oracle = AggregatorV2V3Interface(address(1));

        vm.expectRevert(
            AeraVaultAssetRegistry
                .Aera__NumeraireOracleIsNotZeroAddress
                .selector
        );
        new AeraVaultAssetRegistry(assets, numeraireId, feeToken);
    }

    function test_assetRegistryDeployment_fail_whenNonNumeraireOracleIsZeroAddress(
    ) public {
        assets[nonNumeraireId].oracle = AggregatorV2V3Interface(address(0));

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__OracleIsZeroAddress.selector,
                assets[nonNumeraireId].asset
            )
        );
        new AeraVaultAssetRegistry(assets, numeraireId, feeToken);
    }

    function test_assetRegistryDeployment_fail_when4626OracleIsNotZeroAddress()
        public
    {
        for (uint256 i = 0; i < numAssets; i++) {
            if (assets[i].isERC4626) {
                assets[i].oracle = AggregatorV2V3Interface(address(1));
                vm.expectRevert(
                    abi.encodeWithSelector(
                        AeraVaultAssetRegistry
                            .Aera__4626OracleIsNotZeroAddress
                            .selector,
                        assets[i].asset
                    )
                );
                new AeraVaultAssetRegistry(assets, numeraireId, feeToken);
                assets[i].oracle = AggregatorV2V3Interface(address(0));
            }
        }
    }

    function test_assetRegistryDeployment_success() public {
        assetRegistry =
            new AeraVaultAssetRegistry(assets, numeraireId, feeToken);

        propNumeraire();
        propFeeToken();
        propNumYieldAssets();
        propAssetsSorted();
        propAssets();
    }
}
