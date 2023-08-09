// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/Script.sol";
import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {Operation, AssetValue} from "src/v2/Types.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/AeraVaultHooks.sol";
import "src/v2/TargetSighashLib.sol";

struct OperationAlpha {
    bytes data;
    address target;
    uint256 value;
}

contract TestGuardian is Script, Test {
    bytes4 internal constant _APPROVE_SELECTOR =
        bytes4(keccak256("approve(address,uint256)"));

    bytes4 internal constant _INCREASE_ALLOWANCE_SELECTOR =
        bytes4(keccak256("increaseAllowance(address,uint256)"));

    using stdJson for string;

    uint256 internal senderPrivateKey;
    address internal senderAddress;
    address internal vaultAddress;
    AeraVaultV2 internal vault;

    constructor() {
        senderPrivateKey = uint256(vm.envOr("PRIVATE_KEY", bytes32(0)));
        //senderPrivateKey = 0;

        if (senderPrivateKey == 0) {
            string memory mnemonic = vm.envString("MNEMONIC");
            senderPrivateKey = vm.deriveKey(mnemonic, 1);
        }

        senderAddress = vm.addr(senderPrivateKey);
    }

    function run() public {
        string memory path = string.concat(
            vm.projectRoot(), "/config/AeraVaultTestGuardian.json"
        );
        string memory json = vm.readFile(path);

        vaultAddress = json.readAddress(".vaultAddress");
        vault = AeraVaultV2(vaultAddress);
        AssetValue[] memory holdings = vault.holdings();
        for (uint256 i = 0; i < holdings.length; i++) {
            console.log(address(holdings[i].asset));
            console.log(holdings[i].value);
        }
        vm.label(vaultAddress, "VAULT");
        vm.label(address(vault.hooks()), "HOOKS");
        vm.label(address(vault.assetRegistry()), "ASSET_REGISTRY");
        vm.label(0x5e5057b8D220eb8573Bc342136FdF1d869316D18, "WAPOLWETH");
        address weth = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
        vm.label(weth, "WETH");
        vm.label(0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174, "USDC");

        bytes memory rawOperation;
        rawOperation = json.parseRaw(".operations[0]");
        OperationAlpha memory operation0 =
            abi.decode(rawOperation, (OperationAlpha));
        rawOperation = json.parseRaw(".operations[1]");
        OperationAlpha memory operation1 =
            abi.decode(rawOperation, (OperationAlpha));
        rawOperation = json.parseRaw(".operations[2]");
        OperationAlpha memory operation2 =
            abi.decode(rawOperation, (OperationAlpha));
        rawOperation = json.parseRaw(".operations[3]");
        OperationAlpha memory operation3 =
            abi.decode(rawOperation, (OperationAlpha));
        Operation[] memory operations = new Operation[](4);
        operations[0] = Operation({
            data: operation0.data,
            target: operation0.target,
            value: operation0.value
        });
        //operations[1] = Operation({
        //    data: operation1.data,
        //    target: operation1.target,
        //    value: operation1.value
        //});
        //operations[2] = Operation({
        //    data: operation2.data,
        //    target: operation2.target,
        //    value: operation2.value
        //});
        //operations[3] = Operation({
        //    data: operation3.data,
        //    target: operation3.target,
        //    value: operation3.value
        //});

        //AeraVaultHooks hooks = AeraVaultHooks(address(vault.hooks()));

        //for (uint256 i = 0; i < operations.length; i++) {
        //    console.log(operations[i].target);
        //    console.log(operations[i].value);
        //    console.logBytes(operations[i].data);
        //    bytes4 selector = this.getSelector(operations[i].data);
        //    console.logBytes4(selector);
        //    if (_isAllowanceSelector(selector)) {
        //        continue;
        //    }
        //    TargetSighash sigHash = TargetSighashLib.toTargetSighash(
        //        operations[i].target, selector
        //    );
        //    if (!hooks.targetSighashAllowed(sigHash)) {
        //        TargetSighash sighash = TargetSighashLib.toTargetSighash(
        //            operations[i].target, selector
        //        );
        //        console2.log(TargetSighash.unwrap(sighash));
        //        console2.log("CALL IS NOT ALLOWED", i);
        //    }
        //}

        vm.startBroadcast(senderPrivateKey);
        //hooks.addTargetSighash(
        //    operations[3].target, this.getSelector(operations[3].data)
        //);
        //deal(weth, vaultAddress, 3200000000000000);
        vault.submit(operations);
        vm.stopBroadcast();
    }

    function getSelector(bytes calldata data) public pure returns (bytes4) {
        return bytes4(data[0:4]);
    }

    function _isAllowanceSelector(bytes4 selector)
        internal
        pure
        returns (bool isAllowanceSelector)
    {
        return selector == _APPROVE_SELECTOR
            || selector == _INCREASE_ALLOWANCE_SELECTOR;
    }
}
