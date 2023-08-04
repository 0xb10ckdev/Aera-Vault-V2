// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import "solmate/tokens/ERC20.sol";
import {Aeraform} from "script/utils/Aeraform.sol";

contract ERC20Mock is ERC20 {
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _totalSupply
    ) ERC20(_name, _symbol, _decimals) {
        _mint(msg.sender, _totalSupply);
    }

    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) public {
        _burn(_from, _amount);
    }
}

library ERC20MockFactory {
    function deploy(
        address factory,
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 totalSupply,
        bytes32 salt
    ) internal returns (address deployed) {
        bytes memory bytecode = abi.encodePacked(
            type(ERC20Mock).creationCode,
            abi.encode(name, symbol, decimals, totalSupply)
        );

        deployed = Aeraform.idempotentDeploy(factory, salt, bytecode);
    }
}
