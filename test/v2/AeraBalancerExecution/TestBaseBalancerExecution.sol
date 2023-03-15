// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import {TestBase} from "../../utils/TestBase.sol";
import "solmate/tokens/ERC20.sol";
import "../../../src/v2/dependencies/chainlink/interfaces/AggregatorV2V3Interface.sol";
import "../../../src/v2/dependencies/openzeppelin/IERC20.sol";
import "../../../src/v2/interfaces/IAssetRegistry.sol";
import "../../../src/v2/interfaces/IExecution.sol";
import "../../../src/v2/AeraBalancerExecution.sol";
import "../../../src/v2/AeraVaultAssetRegistry.sol";
import {IOracleMock, OracleMock} from "../../utils/OracleMock.sol";

contract TestBaseBalancerExecution is TestBase {
    address internal _WBTC_ADDRESS = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal _USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal _WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal _BVAULT_ADDRESS =
        0xBA12222222228d8Ba445958a75a0704d566BF2C8;

    AeraBalancerExecution balancerExecution;
    AeraVaultAssetRegistry assetRegistry;
    IAssetRegistry.AssetInformation[] assets;
    IERC20[] erc20Assets;
    uint256 numeraire;

    function setUp() public virtual {
        vm.createSelectFork(vm.envString("ETH_NODE_URI_MAINNET"), 16826100);

        _deploy();
    }

    function _deploy() internal {
        _init();

        address managedPoolAddRemoveTokenLib = deployCode(
            "ManagedPoolAddRemoveTokenLib.sol"
        );

        address circuitBreakerLib = deployCode("CircuitBreakerLib.sol");

        address protocolFeePercentagesProvider = deployCode(
            "ProtocolFeePercentagesProvider.sol",
            abi.encode(_BVAULT_ADDRESS, _ONE, _ONE)
        );

        bytes memory bytecode = abi.encodePacked(
            _getManagedPoolFactoryCreationCode(
                managedPoolAddRemoveTokenLib,
                circuitBreakerLib
            ),
            abi.encode(_BVAULT_ADDRESS, protocolFeePercentagesProvider)
        );

        address managedPoolFactory;

        /// @solidity memory-safe-assembly
        assembly {
            managedPoolFactory := create(
                0,
                add(bytecode, 0x20),
                mload(bytecode)
            )
        }

        assetRegistry = new AeraVaultAssetRegistry(assets, numeraire);

        uint256[] memory weights = new uint256[](3);
        uint256 weightSum;
        for (uint256 i = 0; i < weights.length; i++) {
            weights[i] = _ONE / 3;
            weightSum += weights[i];
        }
        weights[0] = weights[0] + _ONE - weightSum;

        IExecution.NewVaultParams memory vaultParams = IExecution
            .NewVaultParams({
                factory: managedPoolFactory,
                name: "Balancer Execution",
                symbol: "BALANCER EXECUTION",
                poolTokens: erc20Assets,
                weights: weights,
                swapFeePercentage: 1e12,
                assetRegistry: address(assetRegistry),
                description: "Test Execution"
            });
        balancerExecution = new AeraBalancerExecution(vaultParams);

        for (uint256 i = 0; i < 3; i++) {
            erc20Assets[i].approve(address(balancerExecution), 1);
        }

        balancerExecution.initialize(address(this));
    }

    function _init() internal {
        erc20Assets.push(IERC20(_WBTC_ADDRESS));
        erc20Assets.push(IERC20(_USDC_ADDRESS));
        erc20Assets.push(IERC20(_WETH_ADDRESS));

        // USDC
        numeraire = 1;

        for (uint256 i = 0; i < 3; i++) {
            deal(address(erc20Assets[i]), address(this), 1_000_000e18);

            assets.push(
                IAssetRegistry.AssetInformation({
                    asset: erc20Assets[i],
                    isERC4626: false,
                    withdrawable: true,
                    oracle: AggregatorV2V3Interface(
                        i == numeraire ? address(0) : address(new OracleMock(6))
                    )
                })
            );
        }
    }

    function _getManagedPoolFactoryCreationCode(
        address managedPoolAddRemoveTokenLib,
        address circuitBreakerLib
    ) internal returns (bytes memory) {
        string memory creationCodeStr = vm.readFile(
            "./.managed-pool-factory.json"
        );
        creationCodeStr = _replace(
            creationCodeStr,
            "ManagedPoolAddRemoveTokenLib____________",
            _toString(managedPoolAddRemoveTokenLib)
        );
        creationCodeStr = _replace(
            creationCodeStr,
            "CircuitBreakerLib_______________________",
            _toString(circuitBreakerLib)
        );

        return _fromHex(creationCodeStr);
    }

    function _fromHexChar(uint8 c) internal pure returns (uint8) {
        if (bytes1(c) >= bytes1("0") && bytes1(c) <= bytes1("9")) {
            return c - uint8(bytes1("0"));
        }
        if (bytes1(c) >= bytes1("a") && bytes1(c) <= bytes1("f")) {
            return 10 + c - uint8(bytes1("a"));
        }
        if (bytes1(c) >= bytes1("A") && bytes1(c) <= bytes1("F")) {
            return 10 + c - uint8(bytes1("A"));
        }
        revert("fail");
    }

    // Convert an hexadecimal string to raw bytes
    function _fromHex(string memory s) internal view returns (bytes memory) {
        bytes memory ss = bytes(s);
        require(ss.length % 2 == 0); // length must be even
        bytes memory r = new bytes(ss.length / 2);
        for (uint i = 0; i < ss.length / 2; ++i) {
            r[i] = bytes1(
                _fromHexChar(uint8(ss[2 * i])) *
                    16 +
                    _fromHexChar(uint8(ss[2 * i + 1]))
            );
        }
        return r;
    }

    function _replace(
        string memory subject,
        string memory search,
        string memory replacement
    ) internal pure returns (string memory result) {
        assembly {
            let subjectLength := mload(subject)
            let searchLength := mload(search)
            let replacementLength := mload(replacement)

            // Store the mask for sub-word comparisons in the scratch space.
            mstore(0x00, not(0))
            mstore(0x20, 0)

            subject := add(subject, 0x20)
            search := add(search, 0x20)
            replacement := add(replacement, 0x20)
            result := add(mload(0x40), 0x20)

            let k := 0

            let subjectEnd := add(subject, subjectLength)
            if iszero(gt(searchLength, subjectLength)) {
                let subjectSearchEnd := add(sub(subjectEnd, searchLength), 1)
                for {

                } lt(subject, subjectSearchEnd) {

                } {
                    let o := and(searchLength, 31)
                    // Whether the first `searchLength % 32` bytes of
                    // `subject` and `search` matches.
                    let l := iszero(
                        and(
                            xor(mload(subject), mload(search)),
                            mload(sub(0x20, o))
                        )
                    )
                    // Iterate through the rest of `search` and check if any word mismatch.
                    // If any mismatch is detected, `l` is set to 0.
                    for {

                    } and(lt(o, searchLength), l) {

                    } {
                        l := eq(mload(add(subject, o)), mload(add(search, o)))
                        o := add(o, 0x20)
                    }
                    // If `l` is one, there is a match, and we have to copy the `replacement`.
                    if l {
                        // Copy the `replacement` one word at a time.
                        for {
                            o := 0
                        } lt(o, replacementLength) {
                            o := add(o, 0x20)
                        } {
                            mstore(
                                add(result, add(k, o)),
                                mload(add(replacement, o))
                            )
                        }
                        k := add(k, replacementLength)
                        subject := add(subject, searchLength)
                    }
                    // If `l` or `searchLength` is zero.
                    if iszero(mul(l, searchLength)) {
                        mstore(add(result, k), mload(subject))
                        k := add(k, 1)
                        subject := add(subject, 1)
                    }
                }
            }

            let resultRemainder := add(result, k)
            k := add(k, sub(subjectEnd, subject))
            // Copy the rest of the string one word at a time.
            for {

            } lt(subject, subjectEnd) {

            } {
                mstore(resultRemainder, mload(subject))
                resultRemainder := add(resultRemainder, 0x20)
                subject := add(subject, 0x20)
            }
            // Allocate memory for the length and the bytes, rounded up to a multiple of 32.
            mstore(0x40, add(result, and(add(k, 64), not(31))))
            result := sub(result, 0x20)
            mstore(result, k)
        }
    }

    function _toString(address account) internal pure returns (string memory) {
        return _toString(abi.encodePacked(account));
    }

    function _toString(
        bytes memory data
    ) internal pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(data.length * 2);
        for (uint i = 0; i < data.length; i++) {
            str[0 + i * 2] = alphabet[uint(uint8(data[i] >> 4))];
            str[1 + i * 2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }
}
