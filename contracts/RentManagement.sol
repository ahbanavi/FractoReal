// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";

abstract contract RentManagement is ERC721 {
    using Address for address payable;

    /// Only residents
    error OnlyResidents();

    /// Invalid rent amount
    error InvalidRentAmount();

    /// Already paid rent
    error AlreadyPaidRent();

    /// Rent amount to withdraw must be greater than zero
    error InvalidRentAmountToWithdraw();

    mapping(uint256 tokenId => uint256 rent_fee) public rentsFee;
    mapping(uint256 tokenId => address resident) public residents;
    mapping(uint256 tokenId => mapping(uint256 month => uint256 amount))
        public paidRents;

    // mapping for keep track of balances to withraw
    mapping(uint256 tokenId => uint256 amount) public rents;

    uint256 public currentMonth;

    event RentPaid(
        uint256 indexed tokenId,
        uint256 indexed month,
        address payer,
        uint256 amount
    );
    event RentWithdrawn(uint256 indexed month, address to, uint256 amount);

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

        uint256 month = currentMonth;
        if (paidRents[tokenId][month] > 0) revert AlreadyPaidRent();

        paidRents[tokenId][month] += msg.value;
        rents[tokenId] += msg.value;

        emit RentPaid(tokenId, month, msg.sender, msg.value);
    }

    function withdrawRent(uint256 tokenId) external onlyAuthorized(tokenId) {
        uint256 rentAmount = rents[tokenId];
        if (rentAmount == 0) revert InvalidRentAmountToWithdraw();
        rents[tokenId] = 0;
        
        // because rents is set to zero before, we are safe from reentrancy attack
        payable(msg.sender).sendValue(rentAmount);
    }

    function setRentFee(
        uint256 tokenId,
        uint256 rentAmount
    ) external onlyAuthorized(tokenId) {
        rentsFee[tokenId] = rentAmount;
    }

    function setResident(
        uint256 tokenId_,
        address resident
    ) public onlyAuthorized(tokenId_) {
        residents[tokenId_] = resident;
    }

    function getCurrentMonth() public view returns (uint256 month) {
        uint256 epochDay = block.timestamp / 86400;

        assembly {
            epochDay := add(epochDay, 719468)
            let doe := mod(epochDay, 146097)
            let yoe := div(
                sub(
                    sub(add(doe, div(doe, 36524)), div(doe, 1460)),
                    eq(doe, 146096)
                ),
                365
            )
            let doy := sub(
                doe,
                sub(add(mul(365, yoe), shr(2, yoe)), div(yoe, 100))
            )
            let mp := div(add(mul(5, doy), 2), 153)
            month := sub(add(mp, 3), mul(gt(mp, 9), 12))
        }

        return month;
    }

    function setCurrenthMonth() public {
        currentMonth = getCurrentMonth();
    }
}
