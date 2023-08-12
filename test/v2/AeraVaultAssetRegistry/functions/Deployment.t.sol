// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAssetRegistry.sol";

contract DeploymentTest is TestBaseAssetRegistry {
    function test_assetRegistryDeployment_fail_whenNumberOfAssetsExceedsMaximum(
    ) public {
        _createAssets(30, 20);

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry
                    .Aera__NumberOfAssetsExceedsMaximum
                    .selector,
                50
            )
        );
        new AeraVaultAssetRegistry(
            address(this),
            assets,
            numeraireId,
            feeToken
        );
    }

    function test_assetRegistryDeployment_fail_whenInitialOwnerIsZeroAddress()
        public
    {
        _createAssets(1, 0);

        vm.expectRevert(
            AeraVaultAssetRegistry
                .Aera__AssetRegistryInitialOwnerIsZeroAddress
                .selector
        );
        new AeraVaultAssetRegistry(
            address(0),
            assets,
            numeraireId,
            feeToken
        );
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
        new AeraVaultAssetRegistry(
            address(this),
            assets,
            numeraireId,
            feeToken
        );
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
        new AeraVaultAssetRegistry(
            address(this),
            assets,
            invalidNumeraire,
            feeToken
        );
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
        new AeraVaultAssetRegistry(
            address(this),
            assets,
            numeraireId,
            feeToken
        );
    }

    function test_assetRegistryDeployment_fail_whenNumeraireAssetIsMarkedAsERC4626(
    ) public {
        assets[numeraireId].isERC4626 = true;

        vm.expectRevert(
            AeraVaultAssetRegistry
                .Aera__NumeraireAssetIsMarkedAsERC4626
                .selector
        );
        new AeraVaultAssetRegistry(
            address(this),
            assets,
            numeraireId,
            feeToken
        );
    }

    function test_assetRegistryDeployment_fail_whenNumeraireOracleIsNotZeroAddress(
    ) public {
        assets[numeraireId].oracle = AggregatorV2V3Interface(address(1));

        vm.expectRevert(
            AeraVaultAssetRegistry
                .Aera__NumeraireOracleIsNotZeroAddress
                .selector
        );
        new AeraVaultAssetRegistry(
            address(this),
            assets,
            numeraireId,
            feeToken
        );
    }

    function test_assetRegistryDeployment_fail_whenNonNumeraireERC20OracleIsZeroAddress(
    ) public {
        assets[nonNumeraireId].oracle = AggregatorV2V3Interface(address(0));

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__ERC20OracleIsZeroAddress.selector,
                assets[nonNumeraireId].asset
            )
        );
        new AeraVaultAssetRegistry(
            address(this),
            assets,
            numeraireId,
            feeToken
        );
    }

    function test_assetRegistryDeployment_fail_whenERC4626OracleIsNotZeroAddress(
    ) public {
        for (uint256 i = 0; i < numAssets; i++) {
            if (assets[i].isERC4626) {
                assets[i].oracle = AggregatorV2V3Interface(address(1));
                vm.expectRevert(
                    abi.encodeWithSelector(
                        AeraVaultAssetRegistry
                            .Aera__ERC4626OracleIsNotZeroAddress
                            .selector,
                        assets[i].asset
                    )
                );
                new AeraVaultAssetRegistry(address(this), assets, numeraireId, feeToken);
                assets[i].oracle = AggregatorV2V3Interface(address(0));
            }
        }
    }

    function test_assetRegistryDeployment_success() public {
        assetRegistry = new AeraVaultAssetRegistry(
            address(this),
            assets,
            numeraireId,
            feeToken
        );

        propNumeraire();
        propFeeToken();
        propNumYieldAssets();
        propAssetsSorted();
        propAssets();
    }
}
