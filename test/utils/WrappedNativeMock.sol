// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "./dependencies/solmate/ERC20.sol";

contract WrappedNativeMock is ERC20 {
    constructor() ERC20("Wrapped Native", "WETH", 18) {}

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) public {
        _burn(msg.sender, amount);
        (bool success,) = msg.sender.call{value: amount}("");
        require(success, "Transfer failed.");
    }
}
