// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import "erc721a/contracts/ERC721A.sol";
import "erc721a/contracts/extensions/ERC721ABurnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
// import "hardhat/console.sol";

/// Phase one or two has not started yet.
error PhaseSaleNotStarted();
/// Phase one or two has ended.
error PhaseSaleEnded();
/// Invalid signature, you should use our website for minting.
error InvalidSignature();
/// Invalid ETH has been sended.
error InvalidETH();
/// Withdraw failed.
error WithdrawFailed();
/// Contracts are not allowed to mint.
error ContractMintNotAllowed();

contract FractoRealNFT is ERC721A, Ownable {
    using ECDSA for bytes32;

    string private _baseTokenURI;

    uint256 public immutable totalTokens;

    uint256 public phaseOneStartTime = type(uint256).max;
    uint256 public phaseTwoStartTime = type(uint256).max;

    constructor(
        address initialOwner,
        uint256 totalTokens_
    ) ERC721A("FractoRealNFT", "FRN") Ownable(initialOwner) {
        totalTokens = totalTokens_;
    }

    modifier noContract() {
        if (tx.origin != msg.sender) revert ContractMintNotAllowed();
        _;
    }

    function mint(uint256 quantity) external payable onlyOwner {
        // `_mint`'s second argument now takes in a `quantity`, not a `tokenId`.
        _mint(msg.sender, quantity);
    }

    function phaseOneMint(
        bytes calldata signature,
        uint256 tokenId,
        uint256 priceToPay
    ) external payable noContract {
        if (block.timestamp < phaseOneStartTime) revert PhaseSaleNotStarted();
        if (block.timestamp >= phaseTwoStartTime) revert PhaseSaleEnded();

        // TODO: working here
        // verify signature
        if (
            keccak256(abi.encodePacked(msg.sender, address(this)))
                .toEthSignedMessageHash()
                .recover(signature) != owner()
        ) revert InvalidSignature();

        require(tokenId >= 1 && tokenId <= 1000, "Token ID invalid");
        require(msg.value == price, "Price invalid");
        require(!_exists(tokenId), "Token ID already minted");

        _mint(msg.sender, tokenId);
    }

    function setPhaseOneStartTime(uint256 startTime_) external onlyOwner {
        phaseOneStartTime = startTime_;
    }

    function setPhaseTwoStartTime(uint256 startTime_) external onlyOwner {
        phaseTwoStartTime = startTime_;
    }

    /// Withdraw funds
    function withdraw() external onlyOwner {
        (bool success, ) = msg.sender.call{value: address(this).balance}("");
        if (!success) revert WithdrawFailed();
    }

    /// Set base token URI
    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }
}
