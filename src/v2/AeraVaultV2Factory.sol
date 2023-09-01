// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/Create2.sol";
import "@openzeppelin/Ownable2Step.sol";
import "./AeraVaultV2.sol";
import "./interfaces/IAeraVaultV2Factory.sol";
import {VaultParameters} from "./Types.sol";

/// @title AeraVaultV2Factory
/// @notice Used to create new vaults and deploy arbitrary non-payable contracts with create2.
/// @dev Only one instance of the factory will be required per chain.
contract AeraVaultV2Factory is IAeraVaultV2Factory, Ownable2Step {
    /// @notice The address of wrapped native token.
    address public immutable wrappedNativeToken;

    /// STORAGE ///

    /// @notice Vault parameters for vault deployment.
    VaultParameters public override parameters;

    /// EVENTS ///

    /// @notice Emitted when the vault is created.
    /// @param vault Vault address.
    /// @param assetRegistry Asset registry address.
    /// @param guardian Guardian address.
    /// @param feeRecipient Fee recipient address.
    /// @param fee Fee accrued per second, denoted in 18 decimal fixed point format.
    /// @param description Vault description.
    /// @param wrappedNativeToken The address of wrapped native token.
    event VaultCreated(
        address indexed vault,
        address assetRegistry,
        address indexed guardian,
        address indexed feeRecipient,
        uint256 fee,
        string description,
        address wrappedNativeToken
    );

    /// ERRORS ///

    error Aera__DescriptionIsEmpty();
    error Aera__WrappedNativeTokenIsZeroAddress();

    /// FUNCTIONS ///

    /// @notice Initialize the factory contract.
    /// @param wrappedNativeToken_ The address of wrapped native token.
    constructor(address wrappedNativeToken_) {
        if (wrappedNativeToken_ == address(0)) {
            revert Aera__WrappedNativeTokenIsZeroAddress();
        }

        wrappedNativeToken = wrappedNativeToken_;
    }

    /// @inheritdoc IAeraVaultV2Factory
    function create(
        bytes32 salt,
        address owner,
        address assetRegistry,
        address guardian,
        address feeRecipient,
        uint256 fee,
        string calldata description
    ) external override onlyOwner returns (address deployed) {
        // Requirements: confirm that vault has a nonempty description.
        if (bytes(description).length == 0) {
            revert Aera__DescriptionIsEmpty();
        }

        parameters = VaultParameters({
            owner: owner,
            assetRegistry: assetRegistry,
            guardian: guardian,
            feeRecipient: feeRecipient,
            fee: fee
        });

        // Requirements, Effects and Interactions: deploy vault with create2.
        deployed = address(new AeraVaultV2{salt: salt}());

        delete parameters;

        // Log vault creation.
        emit VaultCreated(
            deployed,
            assetRegistry,
            guardian,
            feeRecipient,
            fee,
            description,
            wrappedNativeToken
        );
    }

    /// @inheritdoc IAeraVaultV2Factory
    function computeVaultAddress(bytes32 salt)
        external
        view
        override
        returns (address)
    {
        return Create2.computeAddress(
            salt, keccak256(type(AeraVaultV2).creationCode)
        );
    }

    /// @inheritdoc IAeraVaultV2Factory
    function deploy(
        bytes32 salt,
        bytes calldata code
    ) external override onlyOwner {
        // Amount is 0 as the asset registry and hooks contracts are not payable.
        Create2.deploy(0, salt, code);
    }

    /// @inheritdoc IAeraVaultV2Factory
    function computeAddress(
        bytes32 salt,
        bytes calldata code
    ) external view override returns (address) {
        return Create2.computeAddress(salt, keccak256(code));
    }
}
