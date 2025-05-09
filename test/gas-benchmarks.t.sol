    // SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {FCL_Elliptic_ZZ} from "FreshCryptoLib/FCL_elliptic.sol";
import {Base64Url} from "FreshCryptoLib/utils/Base64Url.sol";
import {Test, console2} from "forge-std/Test.sol";

import {WebAuthn} from "../src/WebAuthn.sol";

contract WebAuthnGasBenchmarks is Test {
    bytes challenge;
    bytes wrongChallenge;
    uint256 x;
    uint256 y;
    WebAuthn.WebAuthnAuth validAuth;
    WebAuthn.WebAuthnAuth wrongChallengeAuth; // challenge mismatch

    function setUp() public {
        challenge = abi.encode(0xf631058a3ba1116acce12396fad0a125b5041c43f8e15723709f81aa8d5f4ccf);
        wrongChallenge = abi.encode(0xdeadbeef); // Different challenge value
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
                Base64Url.encode(wrongChallenge),
                '","origin":"http://localhost:3005","crossOrigin":false}'
            ),
            challengeIndex: 23,
            typeIndex: 1,
            r: 29739767516584490820047863506833955097567272713519339793744591468032609909569,
            s: 45947455641742997809691064512762075989493430661170736817032030660832793108102
        });
    }

    function test_verify_full_path() public {
        bool result = WebAuthn.verify(challenge, false, validAuth, x, y);
        assertTrue(result, "Valid auth should pass verification");
    }

    function test_verify_early_return_challenge() public {
        bool result = WebAuthn.verify(challenge, false, wrongChallengeAuth, x, y);
        assertFalse(result, "Auth with wrong challenge should fail early");
    }
}
