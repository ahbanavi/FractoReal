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

    /// Spend fee failed
    error SpendFailed();

    // event for fee payments
    event FeePaid(uint256 indexed tokenId, address payer, uint256 amount);

    // event for fee spending
    event FeeSpent(address to, uint256 amount);

    FractoRealNFT public immutable erc721;

    address public buildingManager;
    uint256 public feeAmount;

    mapping(uint256 tokenId => uint256 amount) public paidFees;

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

        paidFees[tokenId] += msg.value;

        emit FeePaid(tokenId, msg.sender, msg.value);
    }

    function spendFee(
        uint256 _amount,
        address to
    ) external onlyBuildingManager {
        payable(to).sendValue(_amount);

        emit FeeSpent(to, _amount);
    }

    function setFeeAmount(uint256 _feeAmount) external onlyBuildingManager {
        feeAmount = _feeAmount;
    }

    function setBuildingManager(address newBuildingManager) internal override {
        buildingManager = newBuildingManager;
    }

    function getErc721() public view virtual override returns (FractoRealNFT) {
        return erc721;
    }
}
