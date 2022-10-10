# Delegated NFT

This is an example repository detailing how to use the [Delegate Cash](https://delegate.cash/) public utility for delegating access from one wallet to another.

This repo requires installing [foundry](https://getfoundry.sh), you can run the repo and tests by doing the following:

```sh
forge build
forge test
```

## Delegate What?

Glad you asked anon, [check this lovely diagram](https://twitter.com/delegatecash/status/1578033046984351744) for more details.

> tl;dr please?

You can keep your super-duper valuable ENS domain, ape, POAP or other crazy degen materials in a safe cold wallet, then grant a second wallet access to interact with other contracts on your behalf. 

You control the permissions on the second wallet. If that wallet is compromised, the attacker has no access to the tokens in your cold wallet. 

## Implementaion

A basic example is detailed in this repo:

```sh
src/
    -- DelegateClaimable.sol              # Example of NFT implemeting delegated claim logic
    -- DelegationRegistry.sol             # Registry implementation
    -- IDelegationRegistry.sol            # Registry public interface
test/
    -- DelegateClaim.t.sol                # tests
```

`DelegateClaimable` contains a `BaseOpenMintable721` contract, this is an extremely barebones ERC721 implementation that allows anyone to mint themselves a new NFT from the collection.

You can imagine this as being an existing, extremely popular collection. Let's call them **Delegated Apes** (DAYC).

In this example, we want to allow holders of Delegated Apes some exclusive access to a special minting of a second collection of NFTs, let's call these **Whitelisted Whales** (WWHALE).

A new WWHALE should be *only* available to holders of DAYC, with *each* DAYC allowing *one* minting of a WWHALE. If a user has 2 DAYCs, they can mint 2 WWHALES.

DAYC has pumped recently, and we care about the safety of DAYC holders. So we want to allow them to delegate minting of WWHALEs to a separate hot wallets, so they can keep their DAYC safe when calling the `claim` function.

`DelegatedClaimable721` is an example implementation of a contract that allows a minting of a WWHALE but in a delegated way. It exposes a `claim` function that accepts the token ID of a DAYC, an address to mint the new WWHALE to, and (optionally) *an address separate to the caller that currently holds a DAYC*:

```js

    function claim(uint256 _tokenId, address _to) external returns (uint256 newTokenId);

    function claim(uint256 _tokenId, address _to, address _vault) external returns (uint256 newTokenId);
```

If the caller passes the optional `_vault` argument, the contract will check:

    - The `_vault` has a BAYC in its possession
    - The `msg.sender` is authorized by the `IDelegationRegistry` to act on behalf of the vault, for that token/contract etc.

# Running for yourself

You can see a worked example of the contracts in `/script/DelegateClaimable.s.sol`, run against a network fork to test with the real delegation registry on mainnet (this doesn't cost anything):

```sh
forge script DelegateClaim --fork-url https://rpc.ankr.com/eth -vvvv
```

If you want additional usage examples, check out the [test folder](./test)