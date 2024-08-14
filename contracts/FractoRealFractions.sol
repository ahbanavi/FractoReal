// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/Address.sol";

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
    using Address for address payable;

    event Received(address from, uint256 amount);
    event RentSplited(uint256 indexed tokenId, uint256 rentAmount);
    event RentWithdrawn(
        uint256 indexed tokenId,
        address indexed to,
        uint256 rentAmount
    );

    FractoRealNFT public immutable erc721;
    uint256 public nonSharesRents;

    struct ShareHolders {
        address holder;
        uint256 share;
        uint256 rents;
    }

    mapping(uint256 tokenId => ShareHolders[]) private tokenIdShareHolders;
    mapping(uint256 tokenId => mapping(address holder => uint256 index))
        private tokenIdShareHoldersIndex;

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
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public onlyERC721 {
        _mint(to, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyERC721 {
        _mintBatch(to, ids, amounts, data);
    }

    /**
     * @dev Rebuilds an NFT by burning all tokens of a given ID owned by the caller and transferring the ownership of the ERC721 token to the caller.
     * @param tokenId The ID of the NFT to be rebuilt.
     * @notice This function can only be called by the owner of all tokens of the given ID.
     * @notice The total supply of the given ID must be set.
     * @notice The caller must have ownership of all tokens of the given ID.
     */
    function rebuildNFT(uint256 tokenId) public {
        uint256 tokenIdTotalSupply = totalSupply(tokenId);

        // Check if the token ID is set
        if (tokenIdTotalSupply == 0) revert TokenIdNotSet();

        // Check if the caller owns all tokens of the given ID
        if (balanceOf(msg.sender, tokenId) != tokenIdTotalSupply)
            revert OwnerDoesNotOwnAllTokens();

        // Burn all tokens of the given ID owned by the caller, that means all tokens of the given ID will be burned
        _burn(msg.sender, tokenId, tokenIdTotalSupply);

        // Transfer the ownership of the ERC721 token to the caller
        erc721.safeTransferFrom(address(this), msg.sender, tokenId);
    }

    function getShareHolderInfo(
        uint256 tokenId,
        address holder
    ) external view returns (ShareHolders memory) {
        uint256 index = tokenIdShareHoldersIndex[tokenId][holder];
        if (index == 0) {
            // return zero
            return ShareHolders(address(0), 0, 0);
        }

        return tokenIdShareHolders[tokenId][index - 1];
    }

    /**
     * Splits the rent of a token among its share holders.
     * @param tokenId The ID of the token.
     */
    function splitRent(uint256 tokenId) external {
        // call withdrawRent function of erc721 contract and get the rent amount
        // if the rent amount is zero, it will revert
        uint256 rentAmount = erc721.withdrawRent(tokenId);

        uint256 totalShares = totalSupply(tokenId);

        uint256 sharedRents = 0;
        // for each token owner, calculate the rent amount based on their share
        for (uint256 i = 0; i < tokenIdShareHolders[tokenId].length; i++) {
            uint256 share = tokenIdShareHolders[tokenId][i].share;
            uint256 rent = (share * rentAmount) / totalShares;
            sharedRents += rent;

            // increase the rents of the token owner
            tokenIdShareHolders[tokenId][i].rents += rent;
        }

        // If the total rents shares of token owners is not equal to the total shares of the token,
        // the remaining rent should be given to the owner of this contract.
        // This is because we don't set shares for the owner of this contract while minting to save gas.
        // also there might be a case of uneven shares after dividing, so the remaining rent (1 to 9 wei)
        // is given to the owner for simplicity. if we try to log the remaining rent, it will be lost in gas fees
        // and not worth it.
        if (sharedRents != rentAmount) {
            uint256 notSplitedRents = rentAmount - sharedRents;
            nonSharesRents += notSplitedRents;
        }

        emit RentSplited(tokenId, rentAmount);
    }

    /**
     * Allows a token holder to withdraw their accumulated rent for a specific token.
     * @param tokenId The ID of the token.
     */
    function withdrawRent(uint256 tokenId) external {
        // Retrieve the rent amount for the token holder
        uint256 rentMoney = tokenIdShareHolders[tokenId][
            tokenIdShareHoldersIndex[tokenId][msg.sender] - 1
        ].rents;

        // Set the rent amount to zero to prevent double withdrawal (reentrancy attack)
        tokenIdShareHolders[tokenId][
            tokenIdShareHoldersIndex[tokenId][msg.sender] - 1
        ].rents = 0;

        // Transfer the rent amount to the token holder
        payable(msg.sender).sendValue(rentMoney);

        emit RentWithdrawn(tokenId, msg.sender, rentMoney);
    }

    function withdrawNonSharesRents() external onlyOwner {
        uint256 rentMoney = nonSharesRents;
        nonSharesRents = 0;
        payable(msg.sender).sendValue(rentMoney);
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

            if (from == address(0) && to == owner()) {
                // skip for owner minting to save gas
                unchecked {
                    ++i;
                }
                continue;
            }

            // check if token is locked due to a proposal
            if (isTokenLocked(tokenId)) {
                revert TokenLocked(tokenId);
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
                    ShareHolders({holder: to, share: value, rents: 0})
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
