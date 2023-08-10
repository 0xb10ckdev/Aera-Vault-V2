// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {console} from "forge-std/console.sol";
import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/Script.sol";
import {Script} from "forge-std/Script.sol";
import {Test} from "forge-std/Test.sol";
import {Operation, AssetValue} from "src/v2/Types.sol";
import {DeployScript} from "script/v2/deploy/DeployAeraContracts.s.sol";
import "src/v2/AeraVaultV2.sol";
import "src/v2/AeraVaultHooks.sol";
import "src/v2/TargetSighashLib.sol";
import "@openzeppelin/Strings.sol";

struct OperationAlpha {
    bytes data;
    address target;
    uint256 value;
}

contract TestGuardian is Test, DeployScript {
    bytes4 internal constant _APPROVE_SELECTOR =
        bytes4(keccak256("approve(address,uint256)"));

    bytes4 internal constant _INCREASE_ALLOWANCE_SELECTOR =
        bytes4(keccak256("increaseAllowance(address,uint256)"));

    using stdJson for string;

    uint256 internal senderPrivateKey;
    address internal senderAddress;
    address internal vaultAddress;
    address internal hooksAddress;
    address internal assetRegistryAddress;
    AeraVaultV2 internal vault;
    address weth = 0x7ceB23fD6bC0adD59E62ac25578270cFf1b9f619;
    address usdc = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address waPolWETH = 0x5e5057b8D220eb8573Bc342136FdF1d869316D18;
    Operation[] operations;

    constructor() {
        //vm.setEnv(
        //    "MNEMONIC",
        //    "candy maple cake sugar pudding cream honey rich smooth crumble sweet treat"
        //);
        //console2.log(vm.envString("MNEMONIC"));
    }

    function setUp() public virtual {
        vm.label(weth, "WETH");
        vm.label(waPolWETH, "WAPOLWETH");
        vm.label(usdc, "USDC");

        //string memory rootPath =
        //    string.concat(vm.projectRoot(), "/config/test_guardian");
        //_deployContracts(rootPath);

        //_loadOperations(rootPath);
    }

    function _deployContracts(string memory rootPath) internal {
        (assetRegistryAddress, vaultAddress, hooksAddress) =
        runFromSpecifiedConfigPaths(
            0,
            string.concat(rootPath, "/AeraVaultAssetRegistry.json"),
            string.concat(rootPath, "/AeraVaultV2.json"),
            string.concat(rootPath, "/AeraVaultHooks.json")
        );
        vm.label(vaultAddress, "VAULT");
        vm.label(hooksAddress, "HOOKS");
        vm.label(assetRegistryAddress, "ASSET_REGISTRY");
    }

    function _loadOperations(string memory rootPath) internal {
        string memory guardianPath = string.concat(rootPath, "/Guardian.json");
        string memory json = vm.readFile(guardianPath);

        vault = AeraVaultV2(vaultAddress);
        AssetValue[] memory holdings = vault.holdings();
        for (uint256 i = 0; i < holdings.length; i++) {
            console.log(address(holdings[i].asset));
            console.log(holdings[i].value);
        }

        bytes memory rawOperation;
        for (uint256 i = 0; i < 4; i++) {
            // TODO: see what happens if I try to parse a non-existent operation
            // after the end of the array (and can I make the loading dynamic by
            // stopping at this point)
            rawOperation = json.parseRaw(
                string.concat(".operations[", Strings.toString(i), "]")
            );
            OperationAlpha memory operation =
                abi.decode(rawOperation, (OperationAlpha));
            operations.push(
                Operation({
                    data: operation.data,
                    target: operation.target,
                    value: operation.value
                })
            );
        }
    }
    // can remove, this function is irrelevant now that we are deploying here
    // and have access to source
    //function _checkValidOperations() internal
    //{
    //    AeraVaultHooks hooks = AeraVaultHooks(hooksAddress);

    //    for (uint256 i = 0; i < operations.length; i++) {
    //        console.log(operations[i].target);
    //        console.log(operations[i].value);
    //        console.logBytes(operations[i].data);
    //        bytes4 selector = this.getSelector(operations[i].data);
    //        console.logBytes4(selector);
    //        if (_isAllowanceSelector(selector)) {
    //            continue;
    //        }
    //        TargetSighash sigHash = TargetSighashLib.toTargetSighash(
    //            operations[i].target, selector
    //        );
    //        if (!hooks.targetSighashAllowed(sigHash)) {
    //            TargetSighash sighash = TargetSighashLib.toTargetSighash(
    //                operations[i].target, selector
    //            );
    //            console2.log(TargetSighash.unwrap(sighash));
    //            console2.log("CALL IS NOT ALLOWED", i);
    //            revert Aera__CallIsNotAllowed(operations[i]);
    //        }
    //    }
    //}

    function test_submitSwapAndDeposit() public {
        //hooks.addTargetSighash(
        //    operations[3].target, this.getSelector(operations[3].data)
        //);
        AssetValue[] memory amounts = new AssetValue[](1);
        amounts[0] = AssetValue({asset: IERC20(weth), value: 1e18});
        deal(weth, address(this), amounts[0].value);
        vm.prank(vault.owner());
        vault.deposit(amounts);
        // TODO: test warping, fees, etc
        vm.prank(vault.guardian());
        vault.submit(operations);
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
