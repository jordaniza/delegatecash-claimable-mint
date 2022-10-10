// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "./IDelegationRegistry.sol";

/// @notice barebones NFT with open minting
/// @dev add access control etc for production
contract BaseOpenMintable721 is ERC721 {
    /// @notice numerical incrementing id of the latest token minted
    uint256 private currentTokenId;

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

    /// @dev minting open to anyone
    /// @param _to the address of the recipient
    /// @return currentTokenId the newly minted tokenId
    function mint(address _to) external returns (uint256) {
        currentTokenId++;
        _safeMint(_to, currentTokenId);
        return currentTokenId;
    }
}

/// @notice an example for an NFT contract where claiming is restricted to owners of a linked NFT.
///         claiming can be delegated to another address using the delegate cash registry for safe claiming.
contract DelegatedClaimable721 is ERC721 {
    /* ------ Variables ------ */

    /// @notice numerical incrementing id of the latest token minted
    uint256 private currentTokenId;

    /// @notice address of the DelegationRegistry
    /// @dev see https://delegate.cash/ for more details
    IDelegationRegistry public immutable registry;

    /// @notice the NFT that is required in order to claim this token
    ERC721 public immutable requiredToken;

    /// @notice checks if the orginal tokenId has already been claimed
    mapping(uint256 => bool) public tokenIdClaimed;

    /* ------ Constructor ------ */

    /// @param _registry the address of the delegation registry - immutable
    /// @param _requiredToken the NFT that allows whitelisting of this NFT
    constructor(address _registry, ERC721 _requiredToken, string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
    {
        registry = IDelegationRegistry(_registry);
        requiredToken = _requiredToken;
    }

    /* ------ State Changing Functions ------ */

    /// @notice claim and mint a new member of this collection if token is in the users wallet
    /// @dev this does not require delegation, it is the 'traditional' way
    /// @param _tokenId the id of the token being claimed for, must be in the senders wallet
    /// @param _to address to mint the new NFT
    function claim(uint256 _tokenId, address _to) external returns (uint256 newTokenId) {
        require(requiredToken.ownerOf(_tokenId) == msg.sender, "Only token holder");
        newTokenId = _claim(_to, _tokenId);
        emit Claimed(msg.sender, _tokenId, newTokenId);
    }

    /// @notice claim on behalf of another wallet. Must have delegated permissions.
    /// @dev overloaded, pass the address of the cold wallet to check delegation
    /// @param _tokenId the id of the token being claimed for, must be in the cold wallet
    /// @param _to address to mint the new NFT
    /// @param _vault address of the cold wallet, msg.sender must be a delegate for this wallet
    function claim(uint256 _tokenId, address _to, address _vault) external returns (uint256 newTokenId) {
        require(requiredToken.ownerOf(_tokenId) == _vault, "Vault is not token holder");
        require(
            registry.checkDelegateForToken(msg.sender, _vault, address(requiredToken), _tokenId),
            "Sender is not delegated"
        );
        newTokenId = _claim(_to, _tokenId);
        emit DelegateClaimed(msg.sender, _tokenId, newTokenId, _vault);
    }

    /// @notice internal method to mint the NFT to a new owner
    /// @param _to the address to mint the NFT
    /// @param _tokenIdOriginal the numerical id of the original NFT that acts as the whitelist for this one
    /// @return currentTokenId of the newly minted NFT in this collection
    function _claim(address _to, uint256 _tokenIdOriginal) internal returns (uint256) {
        require(!tokenIdClaimed[_tokenIdOriginal], "Already claimed");
        tokenIdClaimed[_tokenIdOriginal] = true;

        currentTokenId++;
        _safeMint(_to, currentTokenId);
        return currentTokenId;
    }

    /* ----- Events ----- */

    /// @notice emitted on a claim event
    /// @param claimant the address that initiated the claim request
    /// @param originalTokenId that was claimed for
    /// @param newTokenId that was minted
    event Claimed(address indexed claimant, uint256 originalTokenId, uint256 newTokenId);

    /// @notice emitted on a claim event if delegated
    /// @param vault the wallet that delegated access to the claimant and holds the original token
    event DelegateClaimed(address indexed claimant, uint256 originalTokenId, uint256 newTokenId, address vault);
}
