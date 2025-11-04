// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, stdJson, console2} from "forge-std/Test.sol";
import {WebAuthn} from "../src/WebAuthn.sol";

contract ProfileOne is Test {
    using stdJson for string;

    string constant IN_FILE = "/test/fixtures/fcl_vectors.json";

    function setUp() public {
        // Ensure precompile call returns empty for fallback to FCL.
        bytes memory retEmpty = hex"60006000F3";
        vm.etch(address(0x100), retEmpty);
    }

    function test_profileIndex() public {
        uint256 idx = vm.envOr("INDEX", uint256(0));
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, IN_FILE);
        string memory json = vm.readFile(path);
        uint256 count = abi.decode(json.parseRaw(".count"), (uint256));
        if (idx >= count) {
            console2.log("OUT_OF_RANGE");
            return;
        }

        string memory sel = string.concat(".cases.[", vm.toString(idx), "]");
        bytes memory challenge = abi.decode(json.parseRaw(string.concat(sel, ".challenge")), (bytes));
        WebAuthn.WebAuthnAuth memory auth = WebAuthn.WebAuthnAuth({
            authenticatorData: abi.decode(json.parseRaw(string.concat(sel, ".authenticator_data")), (bytes)),
            clientDataJSON: abi.decode(json.parseRaw(string.concat(sel, ".client_data_json.json")), (string)),
            challengeIndex: abi.decode(json.parseRaw(string.concat(sel, ".client_data_json.challenge_index")), (uint256)),
            typeIndex: abi.decode(json.parseRaw(string.concat(sel, ".client_data_json.type_index")), (uint256)),
            r: abi.decode(json.parseRaw(string.concat(sel, ".r")), (uint256)),
            s: abi.decode(json.parseRaw(string.concat(sel, ".s")), (uint256))
        });
        uint256 x = abi.decode(json.parseRaw(string.concat(sel, ".x")), (uint256));
        uint256 y = abi.decode(json.parseRaw(string.concat(sel, ".y")), (uint256));

        bytes32 cdjHash = sha256(bytes(auth.clientDataJSON));
        bytes32 msgHash = sha256(abi.encodePacked(auth.authenticatorData, cdjHash));

        uint256 g0 = gasleft();
        (bool succ, bytes memory ret) = address(this).call(
            abi.encodeWithSelector(this._verifyWrapper.selector, challenge, auth, x, y)
        );
        bool ok = succ && (ret.length == 32 ? abi.decode(ret, (bool)) : false);
        uint256 used = g0 - gasleft();

        console2.log("INDEX:"); console2.logUint(idx);
        console2.log("OK:"); console2.logUint(ok ? 1 : 0);
        console2.log("GAS:"); console2.logUint(used);
        console2.log("MSGHASH:"); console2.logBytes32(msgHash);
        console2.log("R:"); console2.logUint(auth.r);
        console2.log("S:"); console2.logUint(auth.s);
        console2.log("X:"); console2.logUint(x);
        console2.log("Y:"); console2.logUint(y);
    }

    function _verifyWrapper(
        bytes memory challenge,
        WebAuthn.WebAuthnAuth memory auth,
        uint256 x,
        uint256 y
    ) external returns (bool) {
        return WebAuthn.verify(challenge, false, auth, x, y);
    }
}
