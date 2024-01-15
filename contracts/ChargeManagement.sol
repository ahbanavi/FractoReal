// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./BuildingManagerElection.sol";
import "./FractoRealNFT.sol";

contract ChargeManagement is BuildingManagerElection {
    using Address for address payable;

    /// Only the building manager can call this function
    error OnlyBuildingManager();

    /// Insufficient fee amount
    error InvalidFeeAmount();

    /// Already paid fee
    error AlreadyPaidFee();

    /// Spend fee failed
    error SpendFailed();

    // event for fee payments
    event FeePaid(
        uint256 indexed tokenId,
        uint256 indexed month,
        address payer,
        uint256 amount
    );

    // event for fee spending
    event FeeSpent(uint256 indexed month, address to, uint256 amount);

    FractoRealNFT public immutable erc721;

    address public buildingManager;
    uint256 public feeAmount;
    uint256 public currentMonth;

    mapping(uint256 tokenId => mapping(uint256 month => uint256 amount))
        public paidFees;

    modifier onlyBuildingManager() {
        if (msg.sender != buildingManager) revert OnlyBuildingManager();
        _;
    }

    constructor(FractoRealNFT erc721_) {
        erc721 = erc721_;
    }

    function payFee(
        uint256 tokenId
    ) external payable onlyResidentOrUnitOwner(tokenId) {
        if (msg.value != feeAmount) revert InvalidFeeAmount();

        uint256 month = currentMonth;
        if (paidFees[tokenId][month] > 0) revert AlreadyPaidFee();

        paidFees[tokenId][month] += msg.value;

        emit FeePaid(tokenId, month, msg.sender, msg.value);
    }

    function spendFee(
        uint256 _amount,
        address to
    ) external onlyBuildingManager {
        payable(to).sendValue(_amount);

        emit FeeSpent(currentMonth, to, _amount);
    }

    function setFeeAmount(uint256 _feeAmount) external onlyBuildingManager {
        feeAmount = _feeAmount;
    }

    function setBuildingManager(address newBuildingManager) internal override {
        buildingManager = newBuildingManager;
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

    function getErc721() public view virtual override returns (FractoRealNFT) {
        return erc721;
    }
}
