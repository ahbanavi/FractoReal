// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

import "./FractoRealNFT.sol";
import "./FractionsDAO.sol";

/// Only erc721 contract is allowed to mint.
error OnlyERC721Allowed();
/// Only owner or erc721 contract is allowed to mint.
error OnlyOwnerOrERC721Allowed();
/// Owner does not own all tokens of this id
error OwnerDoesNotOwnAllTokens();
//// Token id is not set.
error TokenIdNotSet();

/// @custom:security-contact ahbanavi@gmail.com
contract FractoRealFractions is
    ERC1155,
    ERC1155Supply,
    Ownable,
    ERC721Holder,
    EIP712,
    FractionsDAO
{
    event Received(address from, uint256 amount);

    FractoRealNFT public immutable erc721;
    uint256 public nonSharesRents;

    struct shareHolders {
        address holder;
        uint256 share;
        uint256 rents;
    }

    mapping(uint256 tokenId => shareHolders[]) public tokenIdShareHolders;
    mapping(uint256 => mapping(address => uint256))
        public tokenIdShareHoldersIndex;

    constructor(
        address initialOwner,
        FractoRealNFT erc721_
    ) ERC1155("") Ownable(initialOwner) EIP712("FractoRealFractions", "1") {
        erc721 = erc721_;
    }

    modifier onlyERC721() {
        if (msg.sender != address(erc721)) revert OnlyERC721Allowed();
        _;
    }

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public onlyERC721 {
        _mint(account, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyERC721 {
        _mintBatch(to, ids, amounts, data);
    }

    function burnAllAndTransferERC721(uint256 tokenId) public {
        uint256 tokenIdTotalSupply = totalSupply(tokenId);

        if (tokenIdTotalSupply == 0) revert TokenIdNotSet();
        if (balanceOf(msg.sender, tokenId) != tokenIdTotalSupply)
            revert OwnerDoesNotOwnAllTokens();

        // Burn all tokens of this id for the owner
        _burn(msg.sender, tokenId, tokenIdTotalSupply);

        // Transfer the ownership of the ERC721 token to the owner
        erc721.safeTransferFrom(address(this), msg.sender, tokenId);
    }

    // write a function to withdraw rents from erc721 contract with withdrawRent function
    // the rent should be split between token owners based on their share
    function withdrawAndSplitRent(uint256 tokenId) external {
        // call withdrawRent function of erc721 contract and get the rent amount
        uint256 rentAmount = erc721.withdrawRent(tokenId);

        uint256 totalShares = totalSupply(tokenId);

        uint256 shareHoldersShares = 0;
        // for each token owner, calculate the rent amount based on their share
        for (uint256 i = 0; i < tokenIdShareHolders[tokenId].length; i++) {
            uint256 share = tokenIdShareHolders[tokenId][i].share;
            uint256 rent = (share * rentAmount) / totalShares;
            shareHoldersShares += share;

            // increase the rents of the token owner
            tokenIdShareHolders[tokenId][i].rents += rent;
        }

        // if the total shares of token owners is not equal to total shares of the token, then
        // the remaining rent should be given to the owner of this contract
        // that's because we don't set shares for the owner of this contract while minting to save gas
        if (shareHoldersShares != totalShares) {
            uint256 notSplitedRents = rentAmount - shareHoldersShares;
            nonSharesRents += notSplitedRents;
        }
    }

    function withdrawRent(uint256 tokenId) external {
        uint256 rentMoney = tokenIdShareHolders[tokenId][
            tokenIdShareHoldersIndex[tokenId][msg.sender] - 1
        ].rents;

        tokenIdShareHolders[tokenId][
            tokenIdShareHoldersIndex[tokenId][msg.sender] - 1
        ].rents = 0;

        payable(msg.sender).transfer(rentMoney);
    }

    function withdrawNonSharesRents() external onlyOwner {
        uint256 rentMoney = nonSharesRents;
        nonSharesRents = 0;
        payable(msg.sender).transfer(rentMoney);
    }

    // function to recieve ether
    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal virtual override(ERC1155, ERC1155Supply) {
        super._update(from, to, ids, values);

        // update the share holders
        uint256 len = ids.length;
        for (uint256 i; i != len; ) {
            uint256 tokenId = ids[i];

            if (from == address(0)) {
                // mint
                unchecked {
                    ++i;
                }
                continue;
            }

            // check if token is locked due to a proposal
            if (isTokenLocked(tokenId)) {
                unchecked {
                    ++i;
                }
                continue;
            }

            uint256 value = values[i];

            uint256 fromShareIndex = tokenIdShareHoldersIndex[tokenId][from];
            if (fromShareIndex != 0) {
                uint256 index = tokenIdShareHoldersIndex[tokenId][from] - 1;
                tokenIdShareHolders[tokenId][index].share -= value;
            }

            if (to == address(0)) {
                // burn
                unchecked {
                    ++i;
                }
                continue;
            }

            if (tokenIdShareHoldersIndex[tokenId][to] > 0) {
                uint256 index = tokenIdShareHoldersIndex[tokenId][to] - 1;
                tokenIdShareHolders[tokenId][index].share += value;
            } else {
                tokenIdShareHolders[tokenId].push(
                    shareHolders({holder: to, share: value, rents: 0})
                );
                tokenIdShareHoldersIndex[tokenId][to] = tokenIdShareHolders[
                    tokenId
                ].length;
            }

            unchecked {
                ++i;
            }
        }
    }
}
