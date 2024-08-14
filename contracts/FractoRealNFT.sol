// SPDX-License-Identifier: CC-BY-NC-4.0
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

    constructor(
        address initialOwner,
        uint256 maxSupply_
    ) ERC721("FractoRealNFT", "FNT") Ownable(initialOwner) {
        MAX_SUPPLY = maxSupply_;
    }

    /**
     * @dev Sets the meterages for multiple NFTs.
     * @param ids The array of NFT IDs.
     * @param metrages_ The array of meterages corresponding to the NFT IDs.
     * Requirements:
     * - The `ids` and `metrages_` arrays must have the same length.
     * - Only the contract owner can call this function.
     */
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

    /**
     * @dev Function to mint a token during phase one of the sale.
     * This function checks if the phase one sale has started and if the caller is not a contract.
     * It then checks if the signature is valid and if the price paid is correct.
     * If all checks pass, the token is minted and assigned to the caller.
     *
     * @param signature The signature of the message.
     * @param tokenId The ID of the token to be minted.
     * @param priceToPay The price in wei to be paid for the token.
     */
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

        // everything is ok, mint the token
        _mint(msg.sender, tokenId);
    }

    function setErc1155Address(
        FractoRealFractions erc1155Address
    ) public onlyOwner {
        erc1155 = erc1155Address;
    }

    /**
     * @dev Starts phase two of the minting process.
     * This function checks if the phase two sale has started and if the ERC1155 address is set.
     * It then mints the remaining tokens that have not been minted yet and assigns them to the ERC1155 contract.
     * The token IDs and their corresponding meterages are stored in separate arrays.
     * Finally, it calls the `mintBatch` function of the ERC1155 contract to mint the tokens in a batch.
     * Emits a `phaseTwoStarted` event after the minting process is complete.
     */
    function startPhaseTwoMint() public {
        // Check if phase two sale has started
        if (block.timestamp < phaseTwoStartTime) revert PhaseSaleNotStarted();
        // Check if ERC1155 address is set
        if (address(erc1155) == address(0)) revert ERC1155AddressNotSet();

        // Calculate the number of remaining tokens to be minted
        uint256 arraySize = MAX_SUPPLY - totalSupply();

        // Create arrays to store the unminted tokens and their meterages
        uint256[] memory unmintedTokens = new uint256[](arraySize);
        uint256[] memory unmintedTokensMeteres = new uint256[](arraySize);

        uint256 counter = 0;
        // Iterate through the token IDs to find the unminted tokens
        for (uint256 tokenId_; tokenId_ != MAX_SUPPLY; ) {
            // Check if the token is not owned by anyone
            if (_ownerOf(tokenId_) == address(0)) {
                // Mint the token and assign it to the ERC1155 contract
                _safeMint(address(erc1155), tokenId_);
                // Store the token ID and its meterage in the arrays
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

        // Mint the unminted tokens in a batch using the ERC1155 contract
        erc1155.mintBatch(owner(), unmintedTokens, unmintedTokensMeteres, "");

        // Emit an event to indicate that phase two has started
        emit phaseTwoStarted();
    }

    /**
     * @dev Fractionize a token by transferring it to the ERC1155 contract and minting a new token with fractional ownership.
     * @param from The address of the token owner.
     * @param tokenId_ The ID of the token to be fractionized.
     */
    function fractionize(address from, uint256 tokenId_) public {
        // First transfer to erc1155
        // If the TX sender is not the owner or approved by the owner, then TX revert here.
        // Also, if the erc1155 address is not set, this function reverts with an invalid receiver error.
        safeTransferFrom(from, address(erc1155), tokenId_);

        // If the previous owner of tokenId wasn't `from`, tx reverted in the last function
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
