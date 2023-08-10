// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "forge-std/Test.sol";
import {stdJson} from "forge-std/Script.sol";

/// @title Deployer Contract
/// @dev It deploys contract of a given name with arguments.
///      Used to support deployment of contracts with external linked libraries.
contract Deployer is Test {
    using stdJson for string;

    struct ExternalLibrary {
        string name;
        address addr;
    }

    function deploy(
        string memory name,
        bytes memory args
    ) public virtual returns (address) {
        return deployCode(name, args);
    }

    function deploy(string memory name) public virtual returns (address) {
        return deployCode(name);
    }

    function deploy(
        string memory name,
        bytes memory args,
        uint256 val
    ) public virtual returns (address) {
        return deployCode(name, args, val);
    }

    function deploy(
        string memory name,
        uint256 val
    ) public virtual returns (address) {
        return deployCode(name, val);
    }

    function deploy(
        string memory name,
        ExternalLibrary[] memory libraries
    ) public returns (address addr) {
        bytes memory creationCode = _getCreationCode(name, libraries);

        /// @solidity memory-safe-assembly
        assembly {
            addr := create(0, add(creationCode, 0x20), mload(creationCode))
        }
    }

    function deploy(
        string memory name,
        ExternalLibrary[] memory libraries,
        bytes memory args
    ) public returns (address addr) {
        bytes memory creationCode =
            abi.encodePacked(_getCreationCode(name, libraries), args);

        /// @solidity memory-safe-assembly
        assembly {
            addr := create(0, add(creationCode, 0x20), mload(creationCode))
        }
    }

    function deploy(
        string memory name,
        ExternalLibrary[] memory libraries,
        uint256 val
    ) public returns (address addr) {
        bytes memory creationCode = _getCreationCode(name, libraries);

        /// @solidity memory-safe-assembly
        assembly {
            addr := create(val, add(creationCode, 0x20), mload(creationCode))
        }
    }

    function deploy(
        string memory name,
        ExternalLibrary[] memory libraries,
        bytes memory args,
        uint256 val
    ) public returns (address addr) {
        bytes memory creationCode =
            abi.encodePacked(_getCreationCode(name, libraries), args);

        /// @solidity memory-safe-assembly
        assembly {
            addr := create(val, add(creationCode, 0x20), mload(creationCode))
        }
    }

    function _getPath(string memory name)
        internal
        pure
        returns (string memory)
    {
        return string.concat("./out/", name, ".sol/", name, ".json");
    }

    function _readBytecode(string memory name)
        internal
        returns (string memory)
    {
        string memory path = _getPath(name);
        string memory json = vm.readFile(path);
        return vm.parseJsonString(json, ".bytecode.object");
    }

    function _getSourcePath(string memory name)
        internal
        returns (string memory)
    {
        string memory path = _getPath(name);
        string memory json = vm.readFile(path);
        return vm.parseJsonString(json, ".ast.absolutePath");
    }

    function _getCreationCode(
        string memory name,
        ExternalLibrary[] memory libraries
    ) internal returns (bytes memory) {
        string memory bytecodeStr = _readBytecode(name);
        for (uint256 i = 0; i < libraries.length; i++) {
            string memory sourcePath = _getSourcePath(libraries[i].name);
            string memory placeholder = _toPlaceholder(
                keccak256(abi.encodePacked(sourcePath, ":", libraries[i].name))
            );
            bytecodeStr = _replace(
                bytecodeStr, placeholder, _toString(libraries[i].addr)
            );
        }

        return _fromHex(bytecodeStr);
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
    function _fromHex(string memory s) internal pure returns (bytes memory) {
        bytes memory ss = bytes(s);
        require(ss.length % 2 == 0); // length must be even
        bytes memory r = new bytes(ss.length / 2 - 1);
        for (uint256 i = 1; i < ss.length / 2; ++i) {
            r[i - 1] = bytes1(
                _fromHexChar(uint8(ss[2 * i])) * 16
                    + _fromHexChar(uint8(ss[2 * i + 1]))
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
                for {} lt(subject, subjectSearchEnd) {} {
                    let o := and(searchLength, 31)
                    // Whether the first `searchLength % 32` bytes of
                    // `subject` and `search` matches.
                    let l :=
                        iszero(
                            and(
                                xor(mload(subject), mload(search)),
                                mload(sub(0x20, o))
                            )
                        )
                    // Iterate through the rest of `search` and check if any word mismatch.
                    // If any mismatch is detected, `l` is set to 0.
                    for {} and(lt(o, searchLength), l) {} {
                        l := eq(mload(add(subject, o)), mload(add(search, o)))
                        o := add(o, 0x20)
                    }
                    // If `l` is one, there is a match, and we have to copy the `replacement`.
                    if l {
                        // Copy the `replacement` one word at a time.
                        for { o := 0 } lt(o, replacementLength) {
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
            for {} lt(subject, subjectEnd) {} {
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

    function _toString(address account)
        internal
        pure
        returns (string memory)
    {
        return _toString(abi.encodePacked(account));
    }

    function _toString(bytes memory data)
        internal
        pure
        returns (string memory)
    {
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(data.length * 2);
        for (uint256 i = 0; i < data.length; i++) {
            str[0 + i * 2] = alphabet[uint256(uint8(data[i] >> 4))];
            str[1 + i * 2] = alphabet[uint256(uint8(data[i] & 0x0f))];
        }
        return string(str);
    }

    function _toPlaceholder(bytes32 data)
        internal
        pure
        returns (string memory)
    {
        bytes memory alphabet = "0123456789abcdef";

        bytes memory str = new bytes(17 * 2);
        for (uint256 i = 0; i < 17; i++) {
            str[0 + i * 2] = alphabet[uint256(uint8(data[i] >> 4))];
            str[1 + i * 2] = alphabet[uint256(uint8(data[i] & 0x0f))];
        }
        return string.concat("__$", string(str), "$__");
    }
}
