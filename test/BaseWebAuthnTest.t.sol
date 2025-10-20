// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {WebAuthn} from "../src/WebAuthn.sol";
import {Base64Url} from "FreshCryptoLib/utils/Base64Url.sol";
import {Test} from "forge-std/Test.sol";

abstract contract BaseWebAuthnTest is Test {
    // Fixed public key for tests
    uint256 internal constant PUBKEY_X = 28573233055232466711029625910063034642429572463461595413086259353299906450061;
    uint256 internal constant PUBKEY_Y = 39367742072897599771788408398752356480431855827262528811857788332151452825281;

    // Fixed indices and auth data
    uint256 internal constant CHALLENGE_INDEX = 23;
    uint256 internal constant TYPE_INDEX = 1;
    bytes internal constant AUTH_DATA = hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d9763050000010a";

    // Signature scalars
    uint256 internal constant SIG_R = 29739767516584490820047863506833955097567272713519339793744591468032609909569;
    uint256 internal constant SIG_S = 45947455641742997809691064512762075989493430661170736817032030660832793108102;

    // Default challenge
    bytes internal defaultChallenge;

    // Prebuilt auth fixtures shared by inheritors
    WebAuthn.WebAuthnAuth internal validAuth;
    WebAuthn.WebAuthnAuth internal wrongChallengeAuth;

    function setUp() public virtual {
        defaultChallenge = abi.encode(0xf631058a3ba1116acce12396fad0a125b5041c43f8e15723709f81aa8d5f4ccf);
        validAuth = buildWebAuthnAuth(defaultChallenge);
        wrongChallengeAuth = buildWebAuthnAuth(abi.encode(0xdeadbeef));
    }

    function buildWebAuthnAuth(bytes memory challenge) internal pure returns (WebAuthn.WebAuthnAuth memory auth) {
        auth = WebAuthn.WebAuthnAuth({
            authenticatorData: AUTH_DATA,
            clientDataJSON: string.concat(
                '{"type":"webauthn.get","challenge":"',
                Base64Url.encode(challenge),
                '","origin":"http://localhost:3005","crossOrigin":false}'
            ),
            challengeIndex: CHALLENGE_INDEX,
            typeIndex: TYPE_INDEX,
            r: SIG_R,
            s: SIG_S
        });
    }
}
