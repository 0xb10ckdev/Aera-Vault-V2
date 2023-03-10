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
import "../../utils/ERC20Mock.sol";
import {ERC4626Mock} from "../../utils/ERC4626Mock.sol";
import {IOracleMock, OracleMock} from "../../utils/OracleMock.sol";

contract TestBaseBalancerExecution is TestBase {
    AeraBalancerExecution balancerExecution;
    AeraVaultAssetRegistry assetRegistry;
    IAssetRegistry.AssetInformation[] assets;
    IERC20[] erc20Assets;
    address numeraireAsset;
    uint256 numeraire;
    uint256 nonNumeraire;
    uint256 numAssets;

    function setUp() public virtual {
        _deploy();
    }

    function _deploy() internal {
        address balancerVaultMock = deployCode(
            "BalancerVaultMock.sol",
            abi.encode(address(0))
        );

        address managedPoolAddRemoveTokenLib = deployCode(
            "ManagedPoolAddRemoveTokenLib.sol"
        );

        address circuitBreakerLib = deployCode("CircuitBreakerLib.sol");

        address protocolFeePercentagesProvider = deployCode(
            "ProtocolFeePercentagesProvider.sol",
            abi.encode(balancerVaultMock, _ONE, _ONE)
        );

        address managedPoolFactory;
        string memory creationCodeStr = vm.readFile(
            "./.managed-pool-factory.json"
        );
        creationCodeStr = replace(
            creationCodeStr,
            "ManagedPoolAddRemoveTokenLib____________",
            toString(managedPoolAddRemoveTokenLib)
        );
        creationCodeStr = replace(
            creationCodeStr,
            "CircuitBreakerLib_______________________",
            toString(circuitBreakerLib)
        );

        bytes memory creationCode = fromHex(creationCodeStr);
        bytes memory bytecode = abi.encodePacked(
            creationCode,
            abi.encode(balancerVaultMock, protocolFeePercentagesProvider)
        );

        /// @solidity memory-safe-assembly
        assembly {
            managedPoolFactory := create(
                0,
                add(bytecode, 0x20),
                mload(bytecode)
            )
        }

        _createAssets(4, 2);

        assetRegistry = new AeraVaultAssetRegistry(assets, numeraire);

        uint256[] memory weights = new uint256[](2);
        weights[0] = 1;
        weights[1] = 1;

        IExecution.NewVaultParams memory vaultParams = IExecution
            .NewVaultParams({
                factory: managedPoolFactory,
                name: "Balancer Execution",
                symbol: "BALANCER EXECUTION",
                poolTokens: erc20Assets,
                weights: weights,
                swapFeePercentage: 0,
                assetRegistry: address(assetRegistry),
                description: "Test Execution"
            });
        balancerExecution = new AeraBalancerExecution(vaultParams);
    }

    function _createAssets(uint256 numERC20, uint256 numERC4626) internal {
        for (uint256 i = 0; i < numERC20; i++) {
            (
                ERC20Mock erc20,
                IAssetRegistry.AssetInformation memory asset
            ) = _createAsset();
            erc20Assets.push(IERC20(address(erc20)));

            if (i == 0) {
                numeraireAsset = address(asset.asset);
                asset.oracle = AggregatorV2V3Interface(address(0));
            }

            assets.push(asset);

            if (i < numERC4626) {
                ERC4626Mock erc4626 = new ERC4626Mock(
                    erc20,
                    erc20.name(),
                    erc20.symbol()
                );
                assets.push(
                    IAssetRegistry.AssetInformation({
                        asset: IERC20(address(erc4626)),
                        isERC4626: true,
                        withdrawable: true,
                        oracle: AggregatorV2V3Interface(
                            address(new OracleMock(18))
                        )
                    })
                );
            }
        }

        numAssets = numERC20 + numERC4626;

        for (uint256 i = 0; i < numAssets; i++) {
            for (uint256 j = numAssets - 1; j > i; j--) {
                if (assets[j].asset < assets[j - 1].asset) {
                    IAssetRegistry.AssetInformation memory temp = assets[j];
                    assets[j] = assets[j - 1];
                    assets[j - 1] = temp;
                }
            }

            if (address(assets[i].asset) == numeraireAsset) {
                numeraire = i;
            }
        }

        nonNumeraire = (numeraire + 1) % numAssets;
    }

    function _createAsset()
        internal
        returns (
            ERC20Mock erc20,
            IAssetRegistry.AssetInformation memory newAsset
        )
    {
        erc20 = new ERC20Mock("Token", "TOKEN", 18, 1e30);
        newAsset = IAssetRegistry.AssetInformation({
            asset: IERC20(address(erc20)),
            isERC4626: false,
            withdrawable: true,
            oracle: AggregatorV2V3Interface(address(new OracleMock(18)))
        });

        IOracleMock(address(newAsset.oracle)).setLatestAnswer(int256(_ONE));
    }

    function _generateValidWeights()
        internal
        returns (IAssetRegistry.AssetWeight[] memory weights)
    {
        IAssetRegistry.AssetInformation[] memory registryAssets = assetRegistry
            .assets();
        weights = new IAssetRegistry.AssetWeight[](numAssets);

        uint256 weightSum;
        for (uint256 i = 0; i < numAssets; i++) {
            weights[i] = IAssetRegistry.AssetWeight({
                asset: registryAssets[i].asset,
                weight: _ONE / numAssets
            });
            weightSum += _ONE / numAssets;
        }

        weights[numAssets - 1].weight += _ONE - weightSum;
    }

    function fromHexChar(uint8 c) public pure returns (uint8) {
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
    function fromHex(string memory s) public view returns (bytes memory) {
        bytes memory ss = bytes(s);
        require(ss.length % 2 == 0); // length must be even
        bytes memory r = new bytes(ss.length / 2);
        for (uint i = 0; i < ss.length / 2; ++i) {
            r[i] = bytes1(
                fromHexChar(uint8(ss[2 * i])) *
                    16 +
                    fromHexChar(uint8(ss[2 * i + 1]))
            );
        }
        return r;
    }

    function replace(
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

    function toString(address account) public pure returns (string memory) {
        return toString(abi.encodePacked(account));
    }

    function toString(bytes memory data) public pure returns (string memory) {
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(data.length * 2);
        for (uint i = 0; i < data.length; i++) {
            str[0 + i * 2] = alphabet[uint(uint8(data[i] >> 4))];
            str[1 + i * 2] = alphabet[uint(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }
}
