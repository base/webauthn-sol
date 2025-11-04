#!/usr/bin/env python3
import json
import os
import random
import secrets
import argparse
import base64
import hashlib
from typing import Optional, Tuple

from cryptography.hazmat.primitives.asymmetric import ec, utils
from cryptography.hazmat.primitives import serialization, hashes


# secp256r1 order
P256_N = int("FFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551", 16)
P256_N_DIV_2 = P256_N // 2


def b64url_no_pad(b: bytes) -> str:
    return base64.urlsafe_b64encode(b).decode().rstrip("=")


def to_0x_hex(b: bytes) -> str:
    return "0x" + b.hex()


def calc_message_hash(authenticator_data_hex: str, client_data_json: str) -> bytes:
    auth = bytes.fromhex(authenticator_data_hex[2:] if authenticator_data_hex.startswith("0x") else authenticator_data_hex)
    c_hash = hashlib.sha256(client_data_json.encode()).digest()
    return hashlib.sha256(auth + c_hash).digest()


def make_client_data_json(challenge_bytes: bytes) -> str:
    # Keep the same shape as Utils.getWebAuthnStruct for consistency
    challenge_b64url = b64url_no_pad(challenge_bytes)
    return (
        '{"type":"webauthn.get","challenge":"'
        + challenge_b64url
        + '","origin":"https://sign.coinbase.com","crossOrigin":false}'
    )


def find_indices(client_data_json: str) -> Tuple[int, int]:
    type_index = client_data_json.find('"type":')
    challenge_index = client_data_json.find('"challenge":')
    return type_index, challenge_index


def normalize_s(s: int) -> int:
    return s if s <= P256_N_DIV_2 else P256_N - s


def generate_vectors(count: int, out_path: str, seed: Optional[int] = None) -> None:
    if seed is not None:
        random.seed(seed)

    # Generate a single private key and reuse it (same public key)
    priv = ec.generate_private_key(ec.SECP256R1())
    pub = priv.public_key().public_numbers()
    x = pub.x
    y = pub.y

    # Fixed authenticator data matching BaseWebAuthnTest AUTH_DATA (UP set)
    authenticator_data = "0x49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d9763050000010a"

    cases = []
    for _ in range(count):
        # Variable-length random challenge (1..64 bytes)
        clen = random.randint(1, 64)
        challenge = secrets.token_bytes(clen)
        cdj = make_client_data_json(challenge)
        type_index, challenge_index = find_indices(cdj)

        mhash = calc_message_hash(authenticator_data, cdj)

        # Sign the PREHASHED 32-byte digest
        sig_der = priv.sign(mhash, ec.ECDSA(utils.Prehashed(hashes.SHA256())))
        r, s = utils.decode_dss_signature(sig_der)
        s = normalize_s(s)

        cases.append(
            {
                "challenge": to_0x_hex(challenge),
                "authenticator_data": authenticator_data,
                "client_data_json": {
                    "json": cdj,
                    "type_index": type_index,
                    "challenge_index": challenge_index,
                },
                "message_hash": to_0x_hex(mhash),
                "x": x,
                "y": y,
                "r": r,
                "s": s,
            }
        )

    obj = {"count": len(cases), "cases": cases}

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    with open(out_path, "w") as f:
        json.dump(obj, f, indent=2)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--count", type=int, default=128)
    ap.add_argument("--seed", type=int, default=None)
    ap.add_argument(
        "--out",
        type=str,
        default=os.path.join(os.path.dirname(__file__), "../fixtures/fcl_vectors.json"),
    )
    args = ap.parse_args()
    generate_vectors(args.count, args.out, args.seed)


if __name__ == "__main__":
    main()


