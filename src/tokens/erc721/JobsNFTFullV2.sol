// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {ERC721Burnable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";

/// @custom:security-contact lovro.posel79@gmail.com

contract JobsNFTFullV2 is
    ERC721,
    ERC721Enumerable,
    ERC721Burnable,
    ERC721URIStorage,
    Pausable,
    Ownable,
    ReentrancyGuard,
    ERC2981
{
    // ---- config / ekonomija ----
    uint256 public maxSupply;
    uint256 public mintPrice;
    bool public publicMintEnabled;

    uint256 public maxPerTx = 10;
    uint256 public maxPerWallet = 50;

    mapping(address => uint256) public mintedPerWallet;

    // ---- metadata ----
    bool public metadataFrozen;
    string private baseTokenURI;

    // ---- token id counter -- --
    uint256 private _nextTokenId = 1;

    // ---- eventi ----
    event Minted(address indexed to, uint256 indexed tokenId);
    event BaseURIUpdated(string newBaseURI);
    event MetadataFrozen();
    event PublicMintStatusChanged(bool enabled);
    event MintPriceUpdated(uint256 newPrice);
    event MaxSupplyUpdated(uint256 newMaxSupply);
    event Withdrawn(address indexed to, uint256 amount);

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        uint256 maxSupply_,
        uint256 mintPrice_,
        address royaltyReceiver,
        uint96 royaltyFee // npr. 500 = 5%
    ) ERC721(name_, symbol_) Ownable(msg.sender) {
        baseTokenURI = baseURI_;
        maxSupply = maxSupply_;
        mintPrice = mintPrice_;
        publicMintEnabled = false;

        // EIP-2981 royalties
        _setDefaultRoyalty(royaltyReceiver, royaltyFee);
    }

    // ---------------- MINT ----------------

    function mint(uint256 amount)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        require(publicMintEnabled, "Mint disabled");
        require(amount > 0, "Amount > 0");
        require(amount <= maxPerTx, "Too many per tx");
        require(totalSupply() + amount <= maxSupply, "Max supply reached");
        require(
            mintedPerWallet[msg.sender] + amount <= maxPerWallet,
            "Max per wallet"
        );

        uint256 cost = mintPrice * amount;
        require(msg.value >= cost, "Insufficient ETH");

        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _nextTokenId++;
            _safeMint(msg.sender, tokenId);
            mintedPerWallet[msg.sender] += 1;
            emit Minted(msg.sender, tokenId);
        }

        uint256 excess = msg.value - cost;
        if (excess > 0) {
            (bool ok, ) = msg.sender.call{value: excess}("");
            require(ok, "Refund failed");
        }
    }

    function ownerMint(address to, uint256 amount) external onlyOwner {
        require(totalSupply() + amount <= maxSupply, "Max supply reached");

        for (uint256 i = 0; i < amount; i++) {
            uint256 tokenId = _nextTokenId++;
            _safeMint(to, tokenId);
            emit Minted(to, tokenId);
        }
    }

    function setTokenURI(uint256 tokenId, string calldata uri) external onlyOwner {
        _setTokenURI(tokenId, uri);
    }

    // ---------------- ADMIN ----------------

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        require(!metadataFrozen, "Metadata frozen");
        baseTokenURI = newBaseURI;
        emit BaseURIUpdated(newBaseURI);
    }

    function freezeMetadata() external onlyOwner {
        metadataFrozen = true;
        emit MetadataFrozen();
    }

    function setPublicMintEnabled(bool enabled) external onlyOwner {
        publicMintEnabled = enabled;
        emit PublicMintStatusChanged(enabled);
    }

    function setMintPrice(uint256 newPrice) external onlyOwner {
        mintPrice = newPrice;
        emit MintPriceUpdated(newPrice);
    }

    function setMaxSupply(uint256 newMaxSupply) external onlyOwner {
        require(newMaxSupply >= totalSupply(), "Below current supply");
        maxSupply = newMaxSupply;
        emit MaxSupplyUpdated(newMaxSupply);
    }

    function setMaxPerTx(uint256 newMax) external onlyOwner {
        maxPerTx = newMax;
    }

    function setMaxPerWallet(uint256 newMax) external onlyOwner {
        maxPerWallet = newMax;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // ---------------- WITHDRAW ----------------

    function withdraw(address payable to)
        external
        onlyOwner
        nonReentrant
    {
        uint256 bal = address(this).balance;
        require(bal > 0, "No ETH");
        (bool ok, ) = to.call{value: bal}("");
        require(ok, "Withdraw failed");
        emit Withdrawn(to, bal);
    }

    // ---------------- INTERNAL / OVERRIDES ----------------

    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
        
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    // OZ 5.x: potrebno zbog ERC721 + ERC721Enumerable
    function _update(
        address to,
        uint256 tokenId,
        address auth
    )
        internal
        override(ERC721, ERC721Enumerable)
        whenNotPaused
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 amount)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, amount);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, ERC721URIStorage, ERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
