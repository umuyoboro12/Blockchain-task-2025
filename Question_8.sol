// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

/**
 * @title NFTMarketplace
 *
 * @notice A decentralized marketplace for trading ERC721 NFTs.
 * Allows users to list NFTs for sale, buy listed NFTs, and handles commission
 * deductions as well as royalty payments to creators.
 *
 * Key Features:
 * - Listing NFTs with specified prices
 * - Secure purchase with automatic commission and royalty split
 * - Events emitted for listing, purchase, and sales
 */
contract NFTMarketplace is ReentrancyGuard {
    struct Listing {
        address seller;
        address nftContract;
        uint256 tokenId;
        uint256 price;
        address creator;
        uint256 royaltyPercentage; // e.g., 5 = 5%
    }

    address public owner;
    uint256 public marketplaceCommission = 2; // 2%

    // Mapping from NFT contract + tokenId to its listing
    mapping(address => mapping(uint256 => Listing)) public listings;

    // Events
    event NFTListed(
        address indexed seller,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 price
    );

    event NFTPurchased(
        address indexed buyer,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint256 price,
        uint256 royalty,
        uint256 commission
    );

    event NFTDelisted(
        address indexed seller,
        address indexed nftContract,
        uint256 indexed tokenId
    );

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /**
     * @dev List an NFT for sale with royalty details.
     * @param nftContract Address of the ERC721 contract
     * @param tokenId ID of the NFT
     * @param price Sale price in wei
     * @param creator Original creator of the NFT for royalty
     * @param royaltyPercentage Royalty percentage (e.g., 5 = 5%)
     */
    function listNFT(
        address nftContract,
        uint256 tokenId,
        uint256 price,
        address creator,
        uint256 royaltyPercentage
    ) external {
        require(price > 0, "Price must be greater than zero");
        require(
            IERC721(nftContract).ownerOf(tokenId) == msg.sender,
            "You don't own this NFT"
        );
        require(
            IERC721(nftContract).getApproved(tokenId) == address(this),
            "Marketplace not approved"
        );

        listings[nftContract][tokenId] = Listing({
            seller: msg.sender,
            nftContract: nftContract,
            tokenId: tokenId,
            price: price,
            creator: creator,
            royaltyPercentage: royaltyPercentage
        });

        emit NFTListed(msg.sender, nftContract, tokenId, price);
    }

    /**
     * @dev Buy a listed NFT and pay royalties + commission.
     * @param nftContract Address of the NFT
     * @param tokenId ID of the NFT
     */
    function buyNFT(address nftContract, uint256 tokenId)
        external
        payable
        nonReentrant
    {
        Listing memory item = listings[nftContract][tokenId];
        require(item.price > 0, "NFT not listed for sale");
        require(msg.value >= item.price, "Insufficient payment");

        // Calculate marketplace commission
        uint256 commission = (item.price * marketplaceCommission) / 100;

        // Calculate royalty payment
        uint256 royalty = (item.price * item.royaltyPercentage) / 100;

        // Seller gets the rest
        uint256 sellerProceeds = item.price - commission - royalty;

        // Transfer payments
        if (commission > 0) {
            payable(owner).transfer(commission);
        }
        if (royalty > 0 && item.creator != address(0)) {
            payable(item.creator).transfer(royalty);
        }
        payable(item.seller).transfer(sellerProceeds);

        // Transfer NFT to buyer
        IERC721(nftContract).safeTransferFrom(item.seller, msg.sender, tokenId);

        // Delete the listing
        delete listings[nftContract][tokenId];

        emit NFTPurchased(
            msg.sender,
            nftContract,
            tokenId,
            item.price,
            royalty,
            commission
        );
    }

    /**
     * @dev Delist an NFT.
     * @param nftContract Address of the NFT
     * @param tokenId ID of the NFT
     */
    function delistNFT(address nftContract, uint256 tokenId) external {
        Listing memory item = listings[nftContract][tokenId];
        require(item.seller == msg.sender, "Only seller can delist");

        delete listings[nftContract][tokenId];
        emit NFTDelisted(msg.sender, nftContract, tokenId);
    }

    /**
     * @dev Allows admin to update the marketplace commission.
     * @param newCommission Commission percentage (e.g., 2 = 2%)
     */
    function updateCommission(uint256 newCommission) external onlyOwner {
        require(newCommission <= 10, "Too high"); // Max 10%
        marketplaceCommission = newCommission;
    }

    // Fallback to receive ETH
    receive() external payable {}
}
