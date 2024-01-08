// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

import "./FractoRealNFT.sol";

/// Only erc721 contract is allowed to mint.
error OnlyERC721Allowed();
/// Only owner or erc721 contract is allowed to mint.
error OnlyOwnerOrERC721Allowed();

/// @custom:security-contact ahbanavi@gmail.com
contract FractoRealFractions is ERC1155, Ownable, ERC1155Supply, ERC721Holder {
    FractoRealNFT public immutable erc721;

    constructor(
        address initialOwner,
        FractoRealNFT erc721_
    ) ERC1155("") Ownable(initialOwner) {
        erc721 = erc721_;
    }

    modifier onlyERC721() {
        if (msg.sender != address(erc721)) revert OnlyERC721Allowed();
        _;
    }

    modifier onlyOwnerOrERC721() {
        if (msg.sender != address(erc721) && msg.sender != owner())
            revert OnlyOwnerOrERC721Allowed();
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
    ) public onlyOwnerOrERC721 {
        _mint(account, id, amount, data);
    }

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public onlyOwnerOrERC721 {
        _mintBatch(to, ids, amounts, data);
    }

    // The following functions are overrides required by Solidity.

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155, ERC1155Supply) {
        super._update(from, to, ids, values);
    }
}
