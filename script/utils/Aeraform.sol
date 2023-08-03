// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

interface ICreate2Deployer {
    function deploy(uint256 value, bytes32 salt, bytes memory code) external;

    function computeAddress(
        bytes32 salt,
        bytes32 codeHash
    ) external view returns (address);
}

library Aeraform {
    /// @notice The address of Create2Deployer contract.
    /// @dev Create2Deployer contract is deployed at same addresses on all networks.
    ///      https://github.com/pcaversaccio/create2deployer#deployments-create2deployer
    address internal constant _CREATE2_DEPLOYER =
        0x13b0D85CcB8bf860b6b79AF3029fCA081AE9beF2;

    /// @notice Deploy contract with the given bytecode if it's not deployed yet.
    /// @param salt The salt value to create contract.
    /// @param code Bytecode of contract to be deployed.
    /// @return deployed The address of deployed contract.
    function idempotentDeploy(
        bytes32 salt,
        bytes memory code
    ) internal returns (address deployed) {
        ICreate2Deployer create2Deployer = ICreate2Deployer(_CREATE2_DEPLOYER);

        deployed = create2Deployer.computeAddress(salt, keccak256(code));

        uint256 size;
        assembly {
            size := extcodesize(deployed)
        }

        if (size == 0) {
            create2Deployer.deploy(0, salt, code);
        }
    }
}
