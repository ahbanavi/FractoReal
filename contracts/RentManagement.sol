// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";

abstract contract RentManagement is ERC721 {
    using Address for address payable;

    /// Only residents
    error OnlyResidents();

    /// Invalid rent amount
    error InvalidRentAmount();

    /// Rent amount to withdraw must be greater than zero
    error InvalidRentAmountToWithdraw();

    mapping(uint256 tokenId => uint256 rent_fee) public rentsFee;
    mapping(uint256 tokenId => address resident) public residents;
    mapping(uint256 tokenId => uint256 amount) public paidRents;

    // mapping for keep track of balances to withraw
    mapping(uint256 tokenId => uint256 amount) public rents;

    event RentPaid(uint256 indexed tokenId, address payer, uint256 amount);
    event RentWithdrawn(uint256 indexed tokenId, address to, uint256 amount);
    event RentFeeSet(uint256 indexed tokenId, uint256 amount);
    event ResidentSet(uint256 indexed tokenId, address resident);

    modifier onlyAuthorized(uint256 tokenId) {
        _checkAuthorized(_ownerOf(tokenId), msg.sender, tokenId);
        _;
    }

    modifier onlyResidents(uint256 tokenId) {
        if (residents[tokenId] != msg.sender) revert OnlyResidents();
        _;
    }

    function payRent(uint256 tokenId) external payable onlyResidents(tokenId) {
        if (msg.value != rentsFee[tokenId]) revert InvalidRentAmount();

        paidRents[tokenId] += msg.value;
        rents[tokenId] += msg.value;

        emit RentPaid(tokenId, msg.sender, msg.value);
    }

    function withdrawRent(
        uint256 tokenId
    ) external onlyAuthorized(tokenId) returns (uint256) {
        uint256 rentAmount = rents[tokenId];
        if (rentAmount == 0) revert InvalidRentAmountToWithdraw();

        // re-entrancy protection
        rents[tokenId] = 0;
        emit RentWithdrawn(tokenId, msg.sender, rentAmount);

        // because rents is set to zero before, we are safe from reentrancy attack
        payable(msg.sender).sendValue(rentAmount);

        return rentAmount;
    }

    function setRentFee(
        uint256 tokenId,
        uint256 rentAmount
    ) external onlyAuthorized(tokenId) {
        rentsFee[tokenId] = rentAmount;
        emit RentFeeSet(tokenId, rentAmount);
    }

    function setResident(
        uint256 tokenId_,
        address resident
    ) public onlyAuthorized(tokenId_) {
        residents[tokenId_] = resident;
        emit ResidentSet(tokenId_, resident);
    }
}
