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
{
    namedAccounts: {
        deployer: {
            default: 0, // here this will by default take the first account as deployer
            1: 0, // similarly on mainnet it will take the first account as deployer. Note though that depending on how hardhat network are configured, the account 0 on one network can be different than on another
            4: '0xA296a3d5F026953e17F472B497eC29a5631FB51B', // but for rinkeby it will be a specific address
            "goerli": '0x84b9514E013710b9dD0811c9Fe46b837a4A0d8E0', //it can also specify a specific netwotk name (specified in hardhat.config.js)
        },
        feeCollector:{
            default: 1, // here this will by default take the second account as feeCollector (so in the test this will be a different account than the deployer)
            1: '0xa5610E1f289DbDe94F3428A9df22E8B518f65751', // on the mainnet the feeCollector could be a multi sig
            4: '0xa250ac77360d4e837a13628bC828a2aDf7BabfB3', // on rinkeby it could be another account
        }
    }
}
### Developing 
After cloning the repo, run the tests using Forge, from [Foundry](https://github.com/foundry-rs/foundry?tab=readme-ov-file)
```bash
forge test
```
