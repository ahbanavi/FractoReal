// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/Arrays.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./FractoRealFractions.sol";
import "./RentManagement.sol";

import "hardhat/console.sol";

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
/// Lenght of ids and metrages are not equal.
error LenghtMismatch();
/// ERC1155 address is not set.
error ERC1155AddressNotSet();

/// @custom:security-contact ahbanavi@gmail.com
contract FractoRealNFT is ERC721, ERC721Enumerable, Ownable, RentManagement {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;
    using Arrays for uint256[];
    using Address for address payable;

    FractoRealFractions public erc1155;

    string private _baseTokenURI;
    uint256 public immutable MAX_SUPPLY;

    uint256 public phaseOneStartTime = type(uint256).max;
    uint256 public phaseTwoStartTime = type(uint256).max;

    mapping(uint256 tokenId => uint256) public meterages;

    event phaseOneStartTimeSet(uint256 startTime);
    event phaseTwoStartTimeSet(uint256 startTime);
    event phaseTwoStarted();

    function setMeterages(
        uint256[] memory ids,
        uint256[] memory metrages_
    ) public onlyOwner {
        uint256 length = ids.length;

        if (length != metrages_.length) revert LenghtMismatch();

        unchecked {
            for (uint256 i; i < length; ++i) {
                meterages[ids.unsafeMemoryAccess(i)] = metrages_
                    .unsafeMemoryAccess(i);
            }
        }
    }

    constructor(
        address initialOwner,
        uint256 maxSupply_
    ) ERC721("FractoRealNFT", "FNT") Ownable(initialOwner) {
        MAX_SUPPLY = maxSupply_;
    }

    modifier noContract() {
        if (tx.origin != msg.sender) revert ContractMintNotAllowed();
        _;
    }

    function mint(address to, uint256 tokenId) public onlyOwner {
        _mint(to, tokenId);
    }

    function batchMint(address to, uint256[] memory ids) public onlyOwner {
        uint256 length = ids.length;

        for (uint256 i; i < length; ) {
            _mint(to, ids.unsafeMemoryAccess(i));

            unchecked {
                ++i;
            }
        }
    }

    function phaseOneMint(
        bytes calldata signature,
        uint256 tokenId,
        uint256 priceToPay
    ) external payable noContract {
        if (block.timestamp < phaseOneStartTime) revert PhaseSaleNotStarted();
        if (block.timestamp >= phaseTwoStartTime) revert PhaseSaleEnded();

        // we check for price before signature check to save gas
        if (msg.value != priceToPay) revert InvalidETH();

        // hash is based of msg.sender, contract address, tokenId and priceToPay
        // recover signer from signature
        if (
            keccak256(
                abi.encodePacked(msg.sender, address(this), tokenId, priceToPay)
            ).toEthSignedMessageHash().recover(signature) != owner()
        ) revert InvalidSigner();

        _mint(msg.sender, tokenId);
    }

    function setErc1155Address(
        FractoRealFractions erc1155Address
    ) public onlyOwner {
        erc1155 = erc1155Address;
    }

    function startPhaseTwoMint() public {
        if (block.timestamp < phaseTwoStartTime) revert PhaseSaleNotStarted();
        if (address(erc1155) == address(0)) revert ERC1155AddressNotSet();

        uint256 arraySize = MAX_SUPPLY - totalSupply();

        uint256[] memory unmintedTokens = new uint256[](arraySize);
        uint256[] memory unmintedTokensMeteres = new uint256[](arraySize);

        uint256 counter = 0;
        for (uint256 tokenId_; tokenId_ != MAX_SUPPLY; ) {
            if (_ownerOf(tokenId_) == address(0)) {
                _safeMint(address(erc1155), tokenId_);
                unmintedTokens[counter] = tokenId_;
                unmintedTokensMeteres[counter] = meterages[tokenId_];

                unchecked {
                    ++counter;
                }
            }

            unchecked {
                ++tokenId_;
            }
        }

        erc1155.mintBatch(owner(), unmintedTokens, unmintedTokensMeteres, "");

        emit phaseTwoStarted();
    }

    function fractionize(address from, uint256 tokenId_) public {
        // first transfer to erc1155
        // if tx sender os not the owner or approved by the owner then tx revert here
        safeTransferFrom(from, address(erc1155), tokenId_);

        // if previose owner of tokenId wasn't `from`, tx reverted in the last function
        erc1155.mint(from, tokenId_, meterages[tokenId_], "");
    }

    // Contract time setting
    function setPhaseOneStartTime(uint256 startTime_) external onlyOwner {
        phaseOneStartTime = startTime_;
        emit phaseOneStartTimeSet(startTime_);
    }

    function setPhaseTwoStartTime(uint256 startTime_) external onlyOwner {
        phaseTwoStartTime = startTime_;
        emit phaseTwoStartTimeSet(startTime_);
    }

    /// Withdraw funds
    function withdraw() external onlyOwner {
        payable(msg.sender).sendValue(address(this).balance);
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
