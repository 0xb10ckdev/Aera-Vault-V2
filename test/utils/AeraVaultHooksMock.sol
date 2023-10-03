// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "@openzeppelin/ERC165.sol";
import "src/v2/interfaces/IHooks.sol";

/// @title Mock AeraVaultHooks
contract AeraVaultHooksMock is IHooks, ERC165 {
    /// STORAGE ///

    /// @notice The address of the vault.
    address public vault;

    uint256 public beforeDepositCalled;
    uint256 public afterDepositCalled;
    uint256 public beforeWithdrawCalled;
    uint256 public afterWithdrawCalled;
    uint256 public beforeSubmitCalled;
    uint256 public afterSubmitCalled;
    uint256 public beforeFinalizeCalled;
    uint256 public afterFinalizeCalled;

    /// ERRORS ///

    error Aera__CallerIsNotVault();

    /// MODIFIERS ///

    /// @dev Throws if called by any account other than the vault.
    modifier onlyVault() {
        if (msg.sender != vault) {
            revert Aera__CallerIsNotVault();
        }
        _;
    }

    /// FUNCTIONS ///

    /// @param vault_ Vault address.
    constructor(address vault_) {
        vault = vault_;
    }

    /// @inheritdoc IHooks
    function beforeDeposit(AssetValue[] memory) external override onlyVault {
        beforeDepositCalled++;
    }

    /// @inheritdoc IHooks
    function afterDeposit(AssetValue[] memory) external override onlyVault {
        afterDepositCalled++;
    }

    /// @inheritdoc IHooks
    function beforeWithdraw(AssetValue[] memory) external override onlyVault {
        beforeWithdrawCalled++;
    }

    /// @inheritdoc IHooks
    function afterWithdraw(AssetValue[] memory) external override onlyVault {
        afterWithdrawCalled++;
    }

    /// @inheritdoc IHooks
    function beforeSubmit(Operation[] calldata) external override onlyVault {
        beforeSubmitCalled++;
    }

    /// @inheritdoc IHooks
    function afterSubmit(Operation[] calldata) external override onlyVault {
        afterSubmitCalled++;
    }

    /// @inheritdoc IHooks
    function beforeFinalize() external override onlyVault {
        beforeFinalizeCalled++;
    }

    /// @inheritdoc IHooks
    function afterFinalize() external override onlyVault {
        afterFinalizeCalled++;
    }

    /// @inheritdoc IHooks
    function decommission() external override onlyVault {}

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override
        returns (bool)
    {
        return interfaceId == type(IHooks).interfaceId
            || super.supportsInterface(interfaceId);
    }
}
