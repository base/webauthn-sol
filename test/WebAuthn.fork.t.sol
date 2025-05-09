// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Base64Url} from "FreshCryptoLib/utils/Base64Url.sol";
import {Test, console2} from "forge-std/Test.sol";

import {WebAuthn} from "../src/WebAuthn.sol";

contract WebAuthnForkTest is Test {
    bytes challenge;
    uint256 x;
    uint256 y;
    WebAuthn.WebAuthnAuth validAuth;
    WebAuthn.WebAuthnAuth wrongChallengeAuth;
    uint256 baseFork;
    uint256 ethFork;
    uint256 arbFork;

    function setUp() public {
        // Create forks
        baseFork = vm.createFork("https://mainnet.base.org");
        ethFork = vm.createFork("https://ethereum-rpc.publicnode.com");
        arbFork = vm.createFork("https://arb1.arbitrum.io/rpc");

        challenge = abi.encode(0xf631058a3ba1116acce12396fad0a125b5041c43f8e15723709f81aa8d5f4ccf);
        x = 28573233055232466711029625910063034642429572463461595413086259353299906450061;
        y = 39367742072897599771788408398752356480431855827262528811857788332151452825281;

        // Set up valid auth that will go through full verification
        validAuth = WebAuthn.WebAuthnAuth({
            authenticatorData: hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d9763050000010a",
            clientDataJSON: string.concat(
                '{"type":"webauthn.get","challenge":"', Base64Url.encode(challenge), '","origin":"http://localhost:3005","crossOrigin":false}'
            ),
            challengeIndex: 23,
            typeIndex: 1,
            r: 29739767516584490820047863506833955097567272713519339793744591468032609909569,
            s: 45947455641742997809691064512762075989493430661170736817032030660832793108102
        });

        // Set up auth that will trigger early return due to challenge mismatch
        wrongChallengeAuth = WebAuthn.WebAuthnAuth({
            authenticatorData: hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d9763050000010a",
            clientDataJSON: string.concat(
                '{"type":"webauthn.get","challenge":"',
                Base64Url.encode(abi.encode(0xdeadbeef)),
                '","origin":"http://localhost:3005","crossOrigin":false}'
            ),
            challengeIndex: 23,
            typeIndex: 1,
            r: 29739767516584490820047863506833955097567272713519339793744591468032609909569,
            s: 45947455641742997809691064512762075989493430661170736817032030660832793108102
        });
    }

    function test_verify_full_path_base() public {
        vm.selectFork(baseFork);
        console2.log("Testing on Base (with RIP-7212)");
        bool result = WebAuthn.verify(challenge, false, validAuth, x, y);
        assertTrue(result, "Valid auth should pass verification on Base");
    }

    function test_verify_full_path_eth() public {
        vm.selectFork(ethFork);
        console2.log("Testing on Ethereum (without RIP-7212)");
        bool result = WebAuthn.verify(challenge, false, validAuth, x, y);
        assertTrue(result, "Valid auth should pass verification on Ethereum");
    }

    function test_verify_full_path_arb() public {
        vm.selectFork(arbFork);
        console2.log("Testing on Arbitrum (should have RIP-7212)");
        bool result = WebAuthn.verify(challenge, false, validAuth, x, y);
        assertTrue(result, "Valid auth should pass verification on Arbitrum");
    }

    function test_verify_early_return_challenge_base() public {
        vm.selectFork(baseFork);
        console2.log("Testing early return on Base");
        bool result = WebAuthn.verify(challenge, false, wrongChallengeAuth, x, y);
        assertFalse(result, "Auth with wrong challenge should fail early on Base");
    }

    function test_verify_early_return_challenge_eth() public {
        vm.selectFork(ethFork);
        console2.log("Testing early return on Ethereum");
        bool result = WebAuthn.verify(challenge, false, wrongChallengeAuth, x, y);
        assertFalse(result, "Auth with wrong challenge should fail early on Ethereum");
    }

    function test_verify_early_return_challenge_arb() public {
        vm.selectFork(arbFork);
        console2.log("Testing early return on Arbitrum");
        bool result = WebAuthn.verify(challenge, false, wrongChallengeAuth, x, y);
        assertFalse(result, "Auth with wrong challenge should fail early on Arbitrum");
    }
}
