// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/// Phase one or two has not started yet.
error PhaseSaleNotStarted();
/// Phase one or two has ended.
error PhaseSaleEnded();
/// Invalid signer, you should use our website for minting.
error InvalidSigner();
/// Invalid ETH has been sended.
error InvalidETH();
/// Withdraw failed.
error WithdrawFailed();
/// Contracts are not allowed to mint.
error ContractMintNotAllowed();

/// @custom:security-contact ahbanavi@gmail.com
contract FractoRealNFT is ERC721, ERC721Enumerable, Ownable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    string private _baseTokenURI;

    uint256 public phaseOneStartTime = type(uint256).max;
    uint256 public phaseTwoStartTime = type(uint256).max;

    constructor(
        address initialOwner
    ) ERC721("FractoRealNFT", "FNT") Ownable(initialOwner) {}

    modifier noContract() {
        if (tx.origin != msg.sender) revert ContractMintNotAllowed();
        _;
    }

    function safeMint(address to, uint256 tokenId) public onlyOwner {
        _safeMint(to, tokenId);
    }

    function phaseOneMint(
        bytes calldata signature,
        uint256 tokenId,
        uint256 priceToPay
    ) external payable noContract {
        if (block.timestamp < phaseOneStartTime) revert PhaseSaleNotStarted();
        if (block.timestamp >= phaseTwoStartTime) revert PhaseSaleEnded();
        if (msg.value != priceToPay) revert InvalidETH();

        // hash is based of msg.sender, contract address, tokenId and priceToPay
        bytes32 hash = keccak256(
            abi.encodePacked(
                msg.sender,
                address(this),
                tokenId,
                priceToPay
            )
        );

        // recover signer from signature
        address signer = hash.toEthSignedMessageHash().recover(signature);
        if (signer != owner()) revert InvalidSigner();
        
        _mint(msg.sender, tokenId);
    }

    // Contract time setting
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

    // The following functions are overrides required by Solidity.

    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override(ERC721, ERC721Enumerable) returns (address) {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(
        address account,
        uint128 value
    ) internal override(ERC721, ERC721Enumerable) {
        super._increaseBalance(account, value);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
