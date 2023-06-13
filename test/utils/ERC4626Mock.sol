// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "forge-std/interfaces/IERC20.sol";
import "solmate/tokens/ERC20.sol";
import "solmate/mixins/ERC4626.sol";

/**
 * @dev Mock ERC4626 token with initial total supply.
 *      It just wrap tokens by using ERC4626 of OpenZeppelin.
 *      THIS CONTRACT IS FOR TESTING PURPOSES ONLY. DO NOT USE IN PRODUCTION.
 */
contract ERC4626Mock is ERC4626 {
    bool private paused;

    bool private useMaxDepositAmount;
    uint256 private maxDepositAmount;

    bool private useMaxWithdrawalAmount;
    uint256 private maxWithdrawalAmount;

    // solhint-disable no-empty-blocks
    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol
    ) ERC4626(_asset, _name, _symbol) {}

    function maxDeposit(address receiver)
        public
        view
        virtual
        override
        returns (uint256)
    {
        if (paused) {
            revert("Vault is paused");
        }

        if (useMaxDepositAmount) {
            return maxDepositAmount;
        }

        return super.maxDeposit(receiver);
    }

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function setMaxDepositAmount(uint256 amount, bool use) external {
        maxDepositAmount = amount;
        useMaxDepositAmount = use;
    }

    function maxWithdraw(address owner)
        public
        view
        virtual
        override
        returns (uint256)
    {
        if (paused) {
            revert("Vault is paused");
        }

        if (useMaxWithdrawalAmount) {
            return maxWithdrawalAmount;
        }

        return super.maxWithdraw(owner);
    }

    function setMaxWithdrawalAmount(uint256 amount, bool use) external {
        maxWithdrawalAmount = amount;
        useMaxWithdrawalAmount = use;
    }

    function pause() external {
        paused = true;
    }
}
