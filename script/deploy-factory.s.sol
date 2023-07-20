// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import "src/v2/AeraVaultV2Factory.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/AeraVaultAssetRegistry.sol";
import "src/v2/dependencies/openzeppelin/IERC20.sol";

contract DeployAeraVaultV2Factory is Script {
    mapping(address => uint256) public amounts;

    function run() external {
        vm.startBroadcast();
        AeraVaultV2Factory aeraVaultV2Factory = new AeraVaultV2Factory();
        console2.log(
            "Deployed AeraVaultV2Factory to ", address(aeraVaultV2Factory)
        );
        vm.stopBroadcast();
    }
}
