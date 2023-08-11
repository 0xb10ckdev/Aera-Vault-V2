// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/Create2.sol";
import "@openzeppelin/Ownable2Step.sol";
import "./interfaces/IAeraVaultV2Factory.sol";

/// @title Aera Vault V2 Factory contract.

contract AeraVaultV2Factory is IAeraVaultV2Factory, Ownable2Step {
    /// @notice The address of WETH.
    address public immutable weth;

    /// EVENTS ///

    /// @notice Emitted when the vault is created.
    /// @param vault Vault address.
    /// @param assetRegistry The address of asset registry.
    /// @param guardian The address of guardian.
    /// @param feeRecipient The address of fee recipient.
    /// @param fee Guardian fee per second in 18 decimal fixed point format.
    /// @param description Vault description.
    /// @param weth The address of WETH.
    event VaultCreated(
        address indexed vault,
        address assetRegistry,
        address guardian,
        address feeRecipient,
        uint256 fee,
        string description,
        address weth
    );

    /// ERRORS ///

    error Aera__WETHIsZeroAddress();

    /// FUNCTIONS ///

    /// @notice Initialize the factory contract.
    /// @param weth_ The address of WETH.
    constructor(address weth_) {
        if (weth_ == address(0)) {
            revert Aera__WETHIsZeroAddress();
        }

        weth = weth_;
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
        deployed = address(
            new AeraVaultV2{salt: salt}(
                owner,
                assetRegistry,
                guardian,
                feeRecipient,
                fee,
                description,
                weth
            )
        );

        emit VaultCreated(
            deployed,
            assetRegistry,
            guardian,
            feeRecipient,
            fee,
            description,
            weth
        );
    }

    /// @inheritdoc IAeraVaultV2Factory
    function computeAddress(
        bytes32 salt,
        address owner,
        address assetRegistry,
        address guardian,
        address feeRecipient,
        uint256 fee,
        string calldata description
    ) external view override returns (address) {
        bytes memory bytecode = abi.encodePacked(
            type(AeraVaultV2).creationCode,
            abi.encode(
                owner,
                assetRegistry,
                guardian,
                feeRecipient,
                fee,
                description,
                weth
            )
        );

        return Create2.computeAddress(salt, keccak256(bytecode));
    }

    /// @inheritdoc IAeraVaultV2Factory
    function deploy(
        bytes32 salt,
        bytes calldata code
    ) external override onlyOwner {
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
