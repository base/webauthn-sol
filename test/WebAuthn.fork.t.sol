// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WebAuthn} from "../src/WebAuthn.sol";
import {BaseWebAuthnTest} from "./BaseWebAuthnTest.t.sol";
import {Test} from "forge-std/Test.sol";

contract WebAuthnForkTest is BaseWebAuthnTest {
    uint256 private baseFork;
    uint256 private ethFork;
    uint256 private arbFork;

    function setUp() public override {
        string memory baseRpc = vm.envString("BASE_RPC");
        string memory ethRpc = vm.envString("ETHEREUM_RPC");
        string memory arbRpc = vm.envString("ARBITRUM_RPC");
        baseFork = vm.createFork(baseRpc);
        ethFork = vm.createFork(ethRpc);
        arbFork = vm.createFork(arbRpc);

        super.setUp();
    }

    function test_verify_fullPath_base() public {
        vm.selectFork(baseFork);
        bool result = WebAuthn.verify(defaultChallenge, false, validAuth, PUBKEY_X, PUBKEY_Y);
        assertTrue(result, "Valid auth should pass verification on Base");
    }

    function test_verify_fullPath_eth() public {
        vm.selectFork(ethFork);
        bool result = WebAuthn.verify(defaultChallenge, false, validAuth, PUBKEY_X, PUBKEY_Y);
        assertTrue(result, "Valid auth should pass verification on Ethereum");
    }

    function test_verify_fullPath_arb() public {
        vm.selectFork(arbFork);
        bool result = WebAuthn.verify(defaultChallenge, false, validAuth, PUBKEY_X, PUBKEY_Y);
        assertTrue(result, "Valid auth should pass verification on Arbitrum");
    }

    function test_verify_invalidChallenge_base() public {
        vm.selectFork(baseFork);
        bool result = WebAuthn.verify(defaultChallenge, false, wrongChallengeAuth, PUBKEY_X, PUBKEY_Y);
        assertFalse(result, "Wrong challenge should fail on Base");
    }

    function test_verify_invalidChallenge_eth() public {
        vm.selectFork(ethFork);
        bool result = WebAuthn.verify(defaultChallenge, false, wrongChallengeAuth, PUBKEY_X, PUBKEY_Y);
        assertFalse(result, "Wrong challenge should fail on Ethereum");
    }

    function test_verify_invalidChallenge_arb() public {
        vm.selectFork(arbFork);
        bool result = WebAuthn.verify(defaultChallenge, false, wrongChallengeAuth, PUBKEY_X, PUBKEY_Y);
        assertFalse(result, "Wrong challenge should fail on Arbitrum");
    }
}
