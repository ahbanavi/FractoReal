// SPDX-License-Identifier: CC-BY-NC-4.0
pragma solidity ^0.8.20;

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

    /// event for fee payments
    event FeePaid(uint256 indexed tokenId, address payer, uint256 amount);

    /// event for fee spending
    event FeeSpent(address to, uint256 amount);

    /// event for fee amount change
    event FeeAmountChanged(uint256 newFeeAmount);

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

    /**
     * Allows a resident or unit owner to pay the fee for a specific token ID.
     * @param tokenId The ID of the token for which the fee is being paid.
     */
    function payFee(
        uint256 tokenId
    ) external payable onlyResidentOrUnitOwner(tokenId) {
        if (msg.value != feeAmount) revert InvalidFeeAmount();

        paidFees[tokenId] += msg.value;

        emit FeePaid(tokenId, msg.sender, msg.value);
    }

    /**
     * @dev Transfers a specified amount of Ether to the given address.
     * Only the building manager is allowed to call this function.
     * Emits a `FeeSpent` event after the transfer is completed.
     *
     * @param amount The amount of Ether to be transferred.
     * @param to The address to which the Ether will be transferred.
     */
    function spendFee(uint256 amount, address to) external onlyBuildingManager {
        emit FeeSpent(to, amount);

        payable(to).sendValue(amount);
    }

    /**
     * Sets the fee amount for the building.
     * Can only be called by the building manager.
     * Emits a `FeeAmountChanged` event with the new fee amount.
     * @param newFeeAmount The new fee amount to be set.
     */
    function setFeeAmount(uint256 newFeeAmount) external onlyBuildingManager {
        feeAmount = newFeeAmount;

        emit FeeAmountChanged(newFeeAmount);
    }

    function setBuildingManager(address newBuildingManager) internal override {
        buildingManager = newBuildingManager;
    }

    function getErc721() public view virtual override returns (FractoRealNFT) {
        return erc721;
    }
}
