## Solidity WebAuthn Authentication Assertion Verifier

Webauthn-sol is a Solidity library for verifying WebAuthn authentication assertions. It builds on [Daimo's WebAuthn.sol](https://github.com/daimo-eth/p256-verifier/blob/master/src/WebAuthn.sol).

This library is optimized for Ethereum layer 2 rollup chains but will work on all EVM chains. Signature verification always attempts to use the [RIP-7212 precompile](https://github.com/ethereum/RIPs/blob/master/RIPS/rip-7212.md) and, if this fails, falls back to using [FreshCryptoLib](https://github.com/rdubois-crypto/FreshCryptoLib/blob/master/solidity/src/FCL_ecdsa.sol#L40).

> [!IMPORTANT]  
> FreshCryptoLib uses the `ModExp` precompile (`address(0x05)`), which is not supported on some chains, such as [Polygon zkEVM](https://www.rollup.codes/polygon-zkevm#precompiled-contracts). This library will not work on such chains, unless they support the RIP-7212 precompile. 

Code excerpts

```solidity
struct WebAuthnAuth {
    /// @dev https://www.w3.org/TR/webauthn-2/#dom-authenticatorassertionresponse-authenticatordata
    bytes authenticatorData;
    /// @dev https://www.w3.org/TR/webauthn-2/#dom-authenticatorresponse-clientdatajson
    string clientDataJSON;
    /// The index at which "challenge":"..." occurs in clientDataJSON
    uint256 challengeIndex;
    /// The index at which "type":"..." occurs in clientDataJSON
    uint256 typeIndex;
    /// @dev The r value of secp256r1 signature
    uint256 r;
    /// @dev The s value of secp256r1 signature
    uint256 s;
}

function verify(
    bytes memory challenge,
    bool requireUserVerification,
    WebAuthnAuth memory webAuthnAuth,
    uint256 x,
    uint256 y
) internal view returns (bool) 
```

example usage
```solidity
bytes challenge = abi.encode(0xf631058a3ba1116acce12396fad0a125b5041c43f8e15723709f81aa8d5f4ccf);
uint256 x = 28573233055232466711029625910063034642429572463461595413086259353299906450061;
uint256 y = 39367742072897599771788408398752356480431855827262528811857788332151452825281;
WebAuthn.WebAuthnAuth memory auth = WebAuthn.WebAuthnAuth({
    authenticatorData: hex"49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97630500000101",
    clientDataJSON: string.concat(
        '{"type":"webauthn.get","challenge":"', Base64Url.encode(challenge), '","origin":"http://localhost:3005"}'
        ),
    challengeIndex: 23,
    typeIndex: 1,
    r: 43684192885701841787131392247364253107519555363555461570655060745499568693242,
    s: 22655632649588629308599201066602670461698485748654492451178007896016452673579
});
```

### Developing 
After cloning the repo, run the tests using Forge, from [Foundry](https://github.com/foundry-rs/foundry?tab=readme-ov-file)
```bash
forge test
```

## Verification Gas Limit (VGL) estimation for passkeys

Problem: During ERC‑4337 gas estimation, bundlers simulate validation without a real passkey signature. On RIP‑7212 chains the simulation therefore always falls back to the software (FCL) verifier instead of the cheap precompile, overestimating gas. On non‑7212 chains, both valid and invalid inputs execute the software (FCL) verifier whose gas usage varies by input. Without a stable *valid* signature in simulation, estimates are noisy. We profiled many valid signatures and selected a high‑gas (worst‑case) vector to hardcode for accurate, conservative simulation.

Approach: Provide a simulation‑only entry (`verifySim`) that ignores the caller’s `(r,s,x,y)` at the final step and instead verifies a hardcoded known‑valid P‑256 vector. Simulation then follows the same path as real execution:
- On RIP‑7212 chains: precompile succeeds (cheap, matches onchain).
- Without RIP‑7212: fallback (FCL) runs with a worst‑case valid vector (conservative).

> [!WARNING]
> `verifySim` is for simulation‑only bytecode overrides. Do not deploy it in production contracts or expose it in on‑chain execution paths.

Why we needed a statistical sweep: The FCL (software) verifier’s gas usage is input‑dependent; different valid signatures can consume different amounts of gas. To avoid under‑budgeting on non‑7212 chains, we generated many valid vectors, measured their FCL gas, and selected a high‑gas (worst‑case) valid vector to hardcode for simulation. This yields a stable and slightly conservative VGL.

What’s included here:
- `src/WebAuthn.sol`:
  - `verifySim(...)` for simulation‑only overrides.
- Tooling to generate, profile, and visualize FCL gas usage:
  - `test/helpers/generate_p256_vectors.py`: produces P‑256 WebAuthn assertion vectors.
  - `test/ProfileOne.t.sol`: profiles a single vector index, measuring gas and printing fields.
  - `scripts/profile_fcl_gas.sh`: loops all vectors, writes `test/fixtures/fcl_gas_profile.csv`, and reports the max‑gas row.
  - `scripts/plot_fcl_gas_html.py`: builds `test/fixtures/fcl_gas_hist.html`, an interactive histogram with a “Download PNG” button.

### Why these vectors are representative of FCL gas variance

**What FCL actually sees**
- FCL only receives five values: `message` (32‑byte hash), `r`, `s`, `Qx`, `Qy`. WebAuthn fields upstream are only used to compute `message = sha256(authenticatorData || sha256(clientDataJSON))`.

**Where the gas variance comes from**
- The heavy work is a combined scalar multiplication whose control flow depends on the bit patterns of `u = message * s^-1 mod n` and `v = r * s^-1 mod n`. Different bit patterns lead to slightly different arithmetic paths and gas.

**Why our sampling exercises that variance**
- We vary the challenge and thus the hash of `clientDataJSON`, making the final `message` effectively random across samples.
- ECDSA signing with low‑s normalization (as used in production) still yields `r,s` with the usual distribution; low‑s does not collapse the variability that FCL sees through `u`/`v`.
- We also vary public keys. Even if a real wallet reused one key, the dominant driver of variance is the `u`/`v` bit patterns, not which valid key is used.

**What doesn’t influence FCL gas**
- RP ID hash, flags, counters, or JSON layout do not flow into FCL directly; they only affect the 32‑byte `message`. We’re not fixing the challenge in a way that would reduce `message` diversity.

**Practical takeaway**
- The histogram you see reflects the true variability driver inside FCL. Choosing the max‑gas valid vector from our sweep is a sound, conservative bound for non‑7212 chains and aligns simulations with worst‑case reality.

### Generating P‑256 vectors (Python)
We commit the vector inputs under `test/fixtures`, but you can reproduce or regenerate them locally.

Prereqs:
- Python 3.10+ (macOS: `python3 --version`)

Set up a virtual environment and install deps:
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r test/helpers/requirements.txt
```

Generate vectors (defaults to `test/fixtures/fcl_vectors.json`):
```bash
python3 test/helpers/generate_p256_vectors.py \
  --count 300 \
  --seed 42 \
  --out test/fixtures/fcl_vectors.json
```

Notes:
- `--seed` is optional; provide it for reproducible output.
- The script will create the output directory if it does not exist.

How to reproduce our profiling:
```bash
bash scripts/profile_fcl_gas.sh
python3 scripts/plot_fcl_gas_html.py --csv test/fixtures/fcl_gas_profile.csv --out test/fixtures/fcl_gas_hist.html
open test/fixtures/fcl_gas_hist.html
```

How to use in bundler simulation (conceptual):
- Deploy a “fake implementation” for the wallet where its call site uses `WebAuthn.verifySim(challenge, requireUV, auth, x, y)` instead of `verify`.
- In `eth_estimateUserOperationGas`, supply overrides that point the wallet’s ERC‑1967 implementation to the fake implementation during simulation only. Continue passing dummy signature calldata for shape parity; `verifySim` matches `verify`’s signature but ignores signature/public key at the final step and uses an internal fixed valid vector.

Testing with/without RIP‑7212 locally:
- Foundry doesn’t expose native precompiles. Tests that measure the FCL path etch a tiny stub at `address(0x100)` that returns empty data so the code cleanly falls back to FCL without reverting.

Artifacts you may care about:
- `test/fixtures/fcl_gas_profile.csv`: `index,gas,msgHash,r,s,x,y` for valid vectors.
- `test/fixtures/fcl_gas_hist.html`: interactive histogram of gas counts.

Notes:
- `verifySim` is for simulation‑only bytecode overrides; do not use in production deployments.
- Some generated vectors are invalid due to strict byte‑level checks (clientDataJSON indices, base64url encoding, flags). The pipeline skips invalids automatically and profiles only valid ones.