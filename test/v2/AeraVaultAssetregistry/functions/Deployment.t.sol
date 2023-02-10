// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "../TestBaseAssetRegistry.sol";

contract DeploymentTest is TestBaseAssetRegistry {
    function test_assetRegistryDeployment_fail_whenNumeraireIndexExceedsAssetLength()
        public
    {
        uint256 invalidNumeraire = numAssets + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry
                    .Aera__NumeraireAssetIndexExceedsAssetLength
                    .selector,
                numAssets,
                invalidNumeraire
            )
        );
        new AeraVaultAssetRegistry(assets, invalidNumeraire);
    }

    function test_assetRegistryDeployment_fail_whenAssetOrderIsIncorrect()
        public
    {
        IAssetRegistry.AssetInformation[] memory invalidAssets = assets;
        invalidAssets[0] = assets[1];
        invalidAssets[1] = assets[0];

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__AssetOrderIsIncorrect.selector,
                0
            )
        );
        new AeraVaultAssetRegistry(invalidAssets, numeraire);
    }

    function test_assetRegistryDeployment_fail_whenNumeraireOracleIsNotZeroAddress()
        public
    {
        IAssetRegistry.AssetInformation[] memory invalidAssets = assets;
        invalidAssets[numeraire].oracle = AggregatorV2V3Interface(address(1));

        vm.expectRevert(
            AeraVaultAssetRegistry
                .Aera__NumeraireOracleIsNotZeroAddress
                .selector
        );
        new AeraVaultAssetRegistry(invalidAssets, numeraire);
    }

    function test_assetRegistryDeployment_fail_whenNonNumeraireOracleIsZeroAddress()
        public
    {
        IAssetRegistry.AssetInformation[] memory invalidAssets = assets;
        invalidAssets[nonNumeraire].oracle = AggregatorV2V3Interface(
            address(0)
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__OracleIsZeroAddress.selector,
                assets[nonNumeraire].asset
            )
        );
        new AeraVaultAssetRegistry(invalidAssets, numeraire);
    }

    function test_assetRegistryDeployment_success() public {
        checkRegisteredAssets();
    }
}
