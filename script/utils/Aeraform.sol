// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {IAeraVaultV2Factory} from "src/v2/interfaces/IAeraVaultV2Factory.sol";

library Aeraform {
    /// @notice Deploy contract with the given bytecode if it's not deployed yet.
    /// @param factory The address of AeraVaultV2Factory.
    /// @param salt The salt value to create contract.
    /// @param code Bytecode of contract to be deployed.
    /// @return deployed The address of deployed contract.
    function idempotentDeploy(
        address factory,
        bytes32 salt,
        bytes memory code
    ) internal returns (address deployed) {
        deployed = IAeraVaultV2Factory(factory).computeAddress(salt, code);

        uint256 size;
        assembly {
            size := extcodesize(deployed)
        }

        if (size == 0) {
            IAeraVaultV2Factory(factory).deploy(salt, code);
        }
    }
}
