// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "../TestBaseAssetRegistry.sol";

contract DeploymentTest is TestBaseAssetRegistry {
    address public vaultAddress;

    function setUp() public override {
        super.setUp();

        vaultAddress = factory.computeVaultAddress(
            bytes32(0),
            "Test Vault",
            VaultParameters(address(this), _GUARDIAN, _FEE_RECIPIENT, _MAX_FEE)
        );
    }

    function test_assetRegistryDeployment_fail_whenNumberOfAssetsExceedsMaximum(
    ) public {
        _createAssets(30, 20, 10);

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
            vaultAddress,
            assets,
            IERC20(numeraireToken),
            feeToken,
            wrappedNativeToken,
            AggregatorV2V3Interface(address(0))
        );
    }

    function test_assetRegistryDeployment_fail_whenInitialOwnerIsZeroAddress()
        public
    {
        vm.expectRevert(
            AeraVaultAssetRegistry
                .Aera__AssetRegistryInitialOwnerIsZeroAddress
                .selector
        );
        new AeraVaultAssetRegistry(
            address(0),
            vaultAddress,
            assets,
            IERC20(numeraireToken),
            feeToken,
            wrappedNativeToken,
            AggregatorV2V3Interface(address(0))
        );
    }

    function test_assetRegistryDeployment_fail_whenVaultIsZeroAddress()
        public
    {
        vm.expectRevert(
            AeraVaultAssetRegistry.Aera__VaultIsZeroAddress.selector
        );
        new AeraVaultAssetRegistry(
            address(this),
            address(0),
            assets,
            IERC20(numeraireToken),
            feeToken,
            wrappedNativeToken,
            AggregatorV2V3Interface(address(0))
        );
    }

    function test_assetRegistryDeployment_fail_whenNumeraireTokenIsNotRegistered(
    ) public {
        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry
                    .Aera__NumeraireTokenIsNotRegistered
                    .selector,
                address(1)
            )
        );
        new AeraVaultAssetRegistry(
            address(this),
            vaultAddress,
            assets,
            IERC20(address(1)),
            feeToken,
            wrappedNativeToken,
            AggregatorV2V3Interface(address(0))
        );
    }

    function test_assetRegistryDeployment_fail_whenNumeraireTokenIsERC4626()
        public
    {
        assets[numeraireId].isERC4626 = true;

        vm.expectRevert(
            AeraVaultAssetRegistry.Aera__NumeraireTokenIsERC4626.selector
        );
        new AeraVaultAssetRegistry(
            address(this),
            vaultAddress,
            assets,
            IERC20(numeraireToken),
            feeToken,
            wrappedNativeToken,
            AggregatorV2V3Interface(address(0))
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
            vaultAddress,
            assets,
            IERC20(numeraireToken),
            feeToken,
            wrappedNativeToken,
            AggregatorV2V3Interface(address(0))
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
            vaultAddress,
            assets,
            IERC20(numeraireToken),
            feeToken,
            wrappedNativeToken,
            AggregatorV2V3Interface(address(0))
        );
    }

    function test_assetRegistryDeployment_fail_whenFeeTokenIsERC4626()
        public
    {
        for (uint256 i = 0; i < numAssets; i++) {
            if (assets[i].asset == feeToken) {
                assets[i].isERC4626 = true;
                break;
            }
        }
        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__FeeTokenIsERC4626.selector,
                feeToken
            )
        );
        new AeraVaultAssetRegistry(
            address(this),
            vaultAddress,
            assets,
            IERC20(numeraireToken),
            feeToken,
            wrappedNativeToken,
            AggregatorV2V3Interface(address(0))
        );
    }

    function test_assetRegistryDeployment_fail_whenWrappedNativeTokenIsNotRegistered(
    ) public {
        wrappedNativeToken = IERC20(
            address(
                new ERC20Mock("Wrapped Native Token", "WRAPPED_NATIVE_TOKEN", 18, 1e30)
            )
        );

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry
                    .Aera__WrappedNativeTokenIsNotRegistered
                    .selector,
                wrappedNativeToken
            )
        );
        new AeraVaultAssetRegistry(
            address(this),
            vaultAddress,
            assets,
            IERC20(numeraireToken),
            feeToken,
            wrappedNativeToken,
            AggregatorV2V3Interface(address(0))
        );
    }

    function test_assetRegistryDeployment_fail_whenWrappedNativeTokenIsERC4626(
    ) public {
        assets[wrappedNativeTokenId].isERC4626 = true;

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry.Aera__WrappedNativeTokenIsERC4626.selector,
                wrappedNativeToken
            )
        );
        new AeraVaultAssetRegistry(
            address(this),
            vaultAddress,
            assets,
            IERC20(numeraireToken),
            feeToken,
            wrappedNativeToken,
            AggregatorV2V3Interface(address(0))
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
            vaultAddress,
            assets,
            IERC20(numeraireToken),
            feeToken,
            wrappedNativeToken,
            AggregatorV2V3Interface(address(0))
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
            vaultAddress,
            assets,
            IERC20(numeraireToken),
            feeToken,
            wrappedNativeToken,
            AggregatorV2V3Interface(address(0))
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
                new AeraVaultAssetRegistry(
                    address(this), 
                    vaultAddress,
                    assets, 
                    IERC20(numeraireToken),
                    feeToken,
                    wrappedNativeToken,
                    AggregatorV2V3Interface(address(0))
                );
                assets[i].oracle = AggregatorV2V3Interface(address(0));
            }
        }
    }

    function test_assetRegistryDeployment_fail_whenUnderlyingAssetIsNotInList()
        public
    {
        (
            address newERC20,
            IAssetRegistry.AssetInformation memory newERC20Asset
        ) = _createAsset(false, address(0), 50);
        IAssetRegistry.AssetInformation memory newERC4626Asset;

        for (uint256 i = 51; i < 51000; i++) {
            (, newERC4626Asset) = _createAsset(true, newERC20, i);
            if (newERC4626Asset.asset > assets[numAssets - 1].asset) {
                break;
            }
        }

        assets.push(newERC4626Asset);

        vm.expectRevert(
            abi.encodeWithSelector(
                AeraVaultAssetRegistry
                    .Aera__UnderlyingAssetIsNotRegistered
                    .selector,
                newERC4626Asset.asset,
                newERC20Asset.asset
            )
        );
        new AeraVaultAssetRegistry(
            address(this),
            vaultAddress,
            assets,
            IERC20(numeraireToken),
            feeToken,
            wrappedNativeToken,
            AggregatorV2V3Interface(address(0))
        );
    }

    function test_assetRegistryDeployment_success() public {
        assetRegistry = new AeraVaultAssetRegistry(
            address(this),
            vaultAddress,
            assets,
            IERC20(numeraireToken),
            feeToken,
            wrappedNativeToken,
            AggregatorV2V3Interface(address(0))
        );

        assertEq(assetRegistry.vault(), vaultAddress);

        propNumeraire();
        propFeeToken();
        propNumYieldAssets();
        propAssetsSorted();
        propAssets();
    }
}
