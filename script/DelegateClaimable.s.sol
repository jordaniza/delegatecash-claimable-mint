// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IDelegationRegistry} from "src/IDelegationRegistry.sol";

import {BaseOpenMintable721, DelegatedClaimable721} from "src/DelegateClaimable.sol";

contract DelegatedApe is BaseOpenMintable721 {
    constructor() BaseOpenMintable721("DelegatedApe", "DAYC") {}
}

contract DelegateClaim is Script {
    // the CREATE2 address of the delegation registry
    IDelegationRegistry registry = IDelegationRegistry(0x00000000000076A84feF008CDAbe6409d2FE638B);

    // this contract is the original NFT that we want to keep in a cold wallet
    DelegatedApe ape;

    // this NFT should only be available to DAYC holders
    DelegatedClaimable721 whale;

    // here are the wallets in this scenario
    address kanyeCold = vm.addr(1);
    address kanyeHot = vm.addr(2);

    function run() public {
        // deploy our ape
        ape = new DelegatedApe();

        // kanye mints an ape for themselves
        vm.broadcast(kanyeCold);
        uint256 apeId = ape.mint(kanyeCold);

        // deploy our whale
        whale = new DelegatedClaimable721(address(registry), ape, "Whitelisted Whales", "WWHALE");

        // kanye has ΞΞΞ in their cold wallet, does not want to touch the whale contract directly
        // kanye creates a new hot wallet (kanyeHot) and delegates access
        vm.broadcast(kanyeCold);
        registry.delegateForToken(kanyeHot, address(ape), apeId, true);

        // kanye's hot wallet can claim on behalf of the cold wallet
        // in this scenario they mint the new WWHALE to the cold wallet for safe keeping
        vm.broadcast(kanyeHot);
        whale.claim(
            apeId, // id of the token to claim
            kanyeCold, // send to the cold wallet
            kanyeCold // claim on behalf of the cold wallet
        );

        // if all goes well, check that the cold wallet has both tokens
        console.log("----- Final Balances ------");
        console.log("DAYC:", ape.balanceOf(kanyeCold));
        console.log("WWHALE:", whale.balanceOf(kanyeCold));
    }
}
