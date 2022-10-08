// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {DelegationRegistry} from "src/DelegationRegistry.sol";
import {IDelegationRegistry} from "src/IDelegationRegistry.sol";

import {BaseOpenMintable721, DelegatedClaimable721} from "src/DelegateClaimable.sol";

contract DelegatedApe is BaseOpenMintable721 {
    constructor() BaseOpenMintable721("DelegatedApe", "DAYC") {}
}

contract DelegationRegistryTest is Test {
    DelegationRegistry reg;
    DelegatedApe base;
    DelegatedClaimable721 mint;

    /*  ----- SetUp ------ */

    function setUp() public {
        base = new DelegatedApe();
        reg = new DelegationRegistry();
        mint = new DelegatedClaimable721(address(reg), base, "Whitelisted Whales", "WWHALE");
    }

    /*  ----- helper utils ------ */

    // not zero address nor a smart contract
    // smart contracts need to implement 721 receiver and we are not testing this
    function validateIsEOA(address _user) internal {
        vm.assume(_user != address(0));
        uint256 size;
        assembly {
            size := extcodesize(_user)
        }
        vm.assume(size == 0);
    }

    /*  ----- Tests ------ */

    // can purchase a new base NFT
    function testMintNewBaseNFT(address _user0) public {
        validateIsEOA(_user0);
        uint256 tokenId = base.mint(_user0);
        assertEq(base.balanceOf(_user0), 1);
        assertEq(base.ownerOf(tokenId), _user0);
    }

    // cannot claim the mintable nft without a copy of the nft in first wallet
    function testCannotClaimWithoutBase(address _user0, address _user1) public {
        validateIsEOA(_user0);
        validateIsEOA(_user1);
        vm.assume(_user0 != _user1);

        uint256 tokenId = base.mint(_user0);

        vm.prank(_user1);
        vm.expectRevert("Only token holder");
        mint.claim(tokenId, _user1);
    }

    // can claim the mintable nft with a copy of the nft in first wallet
    function testCanClaimWithBase(address _user0) public {
        validateIsEOA(_user0);

        uint256 tokenId = base.mint(_user0);

        vm.prank(_user0);
        mint.claim(tokenId, _user0);

        assertEq(mint.balanceOf(_user0), 1);
    }

    // cannot claim twice for the same token id
    function testCannotClaimTwiceWithBase(address _user0) public {
        validateIsEOA(_user0);

        uint256 tokenId = base.mint(_user0);

        vm.startPrank(_user0);
        mint.claim(tokenId, _user0);

        vm.expectRevert("Already claimed");
        mint.claim(tokenId, _user0);

        vm.stopPrank();
    }

    // can claim for a new token id
    function testCanClaimTwiceWithMultipleMints(address _user0) public {
        validateIsEOA(_user0);

        uint256 tokenId0 = base.mint(_user0);
        uint256 tokenId1 = base.mint(_user0);

        vm.startPrank(_user0);
        mint.claim(tokenId0, _user0);
        mint.claim(tokenId1, _user0);
        vm.stopPrank();

        assertEq(mint.balanceOf(_user0), 2);
    }

    // can delegate the claimant of the base to a second wallet
    function testCanClaimWithDelegatedBase(address _user0, address _user1) public {
        validateIsEOA(_user0);
        validateIsEOA(_user1);
        vm.assume(_user0 != _user1);

        // mint
        uint256 tokenId = base.mint(_user0);

        // delegate
        vm.prank(_user0);
        reg.delegateForToken(_user1, address(base), tokenId, true);

        vm.prank(_user1);
        // overloaded call will check delegation
        mint.claim(tokenId, _user1, _user0);

        assertEq(mint.balanceOf(_user1), 1);
    }

    // cannot claim twice as a delegate
    function testCannotClaimTwiceWithDelegatedBase(address _user0, address _user1) public {
        validateIsEOA(_user0);
        validateIsEOA(_user1);
        vm.assume(_user0 != _user1);

        // mint
        uint256 tokenId = base.mint(_user0);

        // delegate
        vm.prank(_user0);
        reg.delegateForToken(_user1, address(base), tokenId, true);

        vm.startPrank(_user1);
        mint.claim(tokenId, _user1, _user0);
        vm.expectRevert("Already claimed");
        mint.claim(tokenId, _user1, _user0);
    }

    // cannot claim if owner is not holder
    function testCannotClaimWithDelegateIfOwnerIsNotHolder(address _user0, address _user1, address _user2) public {
        validateIsEOA(_user0);
        validateIsEOA(_user1);
        validateIsEOA(_user2);

        vm.assume(_user0 != _user1 && _user1 != _user2 && _user0 != _user2);

        // mint
        uint256 tokenId = base.mint(_user2);

        // delegate
        vm.prank(_user0);
        reg.delegateForToken(_user1, address(base), tokenId, true);

        vm.prank(_user1);
        vm.expectRevert("Vault is not token holder");
        mint.claim(tokenId, _user1, _user0);
    }

    // cannot claim twice if the holder transfers to a new wallet
    function testCannotClaimIfOwnerTransfers(address _user0, address _user1, address _user2) public {
        validateIsEOA(_user0);
        validateIsEOA(_user1);
        validateIsEOA(_user2);

        vm.assume(_user0 != _user1 && _user1 != _user2 && _user0 != _user2);

        // mint
        uint256 tokenId = base.mint(_user0);

        // delegate
        vm.startPrank(_user0);
        reg.delegateForToken(_user1, address(base), tokenId, true);
        base.safeTransferFrom(address(_user0), _user2, tokenId);
        vm.stopPrank();

        vm.prank(_user1);
        vm.expectRevert("Vault is not token holder");
        mint.claim(tokenId, _user1, _user0);
    }

    function testCannotClaimTwiceForSameId(address _user0, address _user1, address _user2) public {
        validateIsEOA(_user0);
        validateIsEOA(_user1);
        validateIsEOA(_user2);

        vm.assume(_user0 != _user1 && _user1 != _user2 && _user0 != _user2);

        // mint
        uint256 tokenId = base.mint(_user0);

        // delegate to the first user
        vm.prank(_user0);
        reg.delegateForToken(_user1, address(base), tokenId, true);

        // claim for the first user
        vm.prank(_user1);
        mint.claim(tokenId, _user1, _user0);

        // transfer to a new vault
        vm.prank(_user0);
        base.safeTransferFrom(_user0, _user2, tokenId);

        // delegate to new hot wallet
        vm.prank(_user2);
        reg.delegateForToken(_user1, address(base), tokenId, true);

        // should revert
        vm.startPrank(_user1);
        vm.expectRevert("Already claimed");
        mint.claim(tokenId, _user1, _user2);
    }

    // can claim for multiple token Ids
    function testCanDelegateClaimForMultipleIds(address _user0, address _user1) public {
        validateIsEOA(_user0);
        validateIsEOA(_user1);

        vm.assume(_user0 != _user1);

        // mint
        uint256 tokenId0 = base.mint(_user0);
        uint256 tokenId1 = base.mint(_user0);

        // delegate, this time for all ids owned by the cold wallet
        vm.prank(_user0);
        reg.delegateForContract(_user1, address(base), true);

        vm.startPrank(_user1);
        mint.claim(tokenId0, _user1, _user0);
        mint.claim(tokenId1, _user1, _user0);
    }

    // cannot claim if not delegated
    function testCannotClaimIfNotDelegated(address _user0, address _user1, address _user2) public {
        validateIsEOA(_user0);
        validateIsEOA(_user1);
        validateIsEOA(_user2);

        vm.assume(_user0 != _user1 && _user1 != _user2 && _user0 != _user2);

        // mint
        uint256 tokenId = base.mint(_user0);

        // delegate
        vm.prank(_user0);
        reg.delegateForToken(_user1, address(base), tokenId, true);

        // attempt to claim as user2
        vm.prank(_user2);
        vm.expectRevert("Sender is not delegated");
        mint.claim(tokenId, _user2, _user0);
    }

    // can revoke delegation
    function testCanRevokeDelegation(address _user0, address _user1) public {
        validateIsEOA(_user0);
        validateIsEOA(_user1);

        vm.assume(_user0 != _user1);

        // mint
        uint256 tokenId = base.mint(_user0);

        // delegate, then revoke
        vm.startPrank(_user0);
        reg.delegateForContract(_user1, address(base), true);
        reg.revokeDelegate(_user1);
        vm.stopPrank();

        // delegate can no longer claim
        vm.prank(_user1);
        vm.expectRevert("Sender is not delegated");
        mint.claim(tokenId, _user1, _user0);
    }

    // owner transfers to delegate - should behave predictably
    function testSomeoneDoesntUnderstandDelegation(address _user0, address _user1) public {
        validateIsEOA(_user0);
        validateIsEOA(_user1);

        vm.assume(_user0 != _user1);

        // mint
        uint256 tokenId = base.mint(_user0);

        // delegate, then transfer to delegate for some reason
        // (will definitely happen if I know degens)
        vm.startPrank(_user0);
        reg.delegateForContract(_user1, address(base), true);
        base.safeTransferFrom(_user0, _user1, tokenId);
        vm.stopPrank();

        // can't claim on behalf of someone with no tokens
        vm.startPrank(_user1);
        vm.expectRevert("Vault is not token holder");
        mint.claim(tokenId, _user1, _user0);

        // should claim normally
        mint.claim(tokenId, _user1);
        vm.stopPrank();

        assertEq(mint.balanceOf(_user1), 1);
    }
}
