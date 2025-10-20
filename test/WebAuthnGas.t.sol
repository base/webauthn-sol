// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WebAuthn} from "../src/WebAuthn.sol";
import {BaseWebAuthnTest} from "./BaseWebAuthnTest.t.sol";
import {Test} from "forge-std/Test.sol";

contract WebAuthnGasBenchmarks is BaseWebAuthnTest {
    function test_verify_valid_signature_path() public {
        bool result = WebAuthn.verify(defaultChallenge, false, validAuth, PUBKEY_X, PUBKEY_Y);
        assertTrue(result, "Valid auth should pass verification");
    }

    function test_verify_invalid_challenge_path() public {
        bool result = WebAuthn.verify(defaultChallenge, false, wrongChallengeAuth, PUBKEY_X, PUBKEY_Y);
        assertFalse(result, "Auth with wrong challenge should fail verification");
    }
}
