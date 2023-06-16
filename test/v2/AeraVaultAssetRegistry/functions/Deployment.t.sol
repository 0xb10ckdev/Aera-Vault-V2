// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "../TestBaseAssetRegistry.sol";

contract DeploymentTest is TestBaseAssetRegistry {
    function setUp() public override {
        _createAssets(4, 2);

        feeToken = assets[numeraire].asset;
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
        new AeraVaultAssetRegistry(assets, numeraire, feeToken);
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
        new AeraVaultAssetRegistry(assets, numeraire, feeToken);
    }

    function test_assetRegistryDeployment_fail_whenNumeraireOracleIsNotZeroAddress(
    ) public {
        assets[numeraire].oracle = AggregatorV2V3Interface(address(1));

        vm.expectRevert(
            AeraVaultAssetRegistry
                .Aera__NumeraireOracleIsNotZeroAddress
                .selector
        );
        new AeraVaultAssetRegistry(assets, numeraire, feeToken);
    }

    function test_assetRegistryDeployment_fail_whenNonNumeraireOracleIsZeroAddress(
    ) public {
        assets[nonNumeraire].oracle = AggregatorV2V3Interface(address(0));

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__OracleIsZeroAddress.selector,
                assets[nonNumeraire].asset
            )
        );
        new AeraVaultAssetRegistry(assets, numeraire, feeToken);
    }

    function test_assetRegistryDeployment_success() public {
        assetRegistry = new AeraVaultAssetRegistry(assets, numeraire, feeToken);

        propNumeraire();
        propFeeToken();
        propNumYieldAssets();
        propAssetsSorted();
        propAssets();
    }
}
