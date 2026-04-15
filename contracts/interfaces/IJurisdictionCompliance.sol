// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IJurisdictionCompliance
 * @dev Interface for jurisdiction-aware transfer restriction checks
 */
interface IJurisdictionCompliance {

    // --- Events ---

    event InvestorRegistered(address indexed investor, bytes32 jurisdiction, bytes32 category);
    event InvestorUpdated(address indexed investor, bytes32 oldJurisdiction, bytes32 newJurisdiction, bytes32 oldCategory, bytes32 newCategory);
    event InvestorRemoved(address indexed investor);
    event TransferAllowed(bytes32 indexed fromJurisdiction, bytes32 indexed toJurisdiction);
    event TransferBlocked(bytes32 indexed fromJurisdiction, bytes32 indexed toJurisdiction);
    event CategoryTransferAllowed(bytes32 indexed fromCategory, bytes32 indexed toCategory);
    event CategoryTransferBlocked(bytes32 indexed fromCategory, bytes32 indexed toCategory);

    // --- Investor Management ---

    /**
     * @notice Register a new investor with jurisdiction and category
     * @param _investor Investor wallet address
     * @param _jurisdiction Jurisdiction code
     * @param _category Investor category
     */
    function registerInvestor(address _investor, bytes32 _jurisdiction, bytes32 _category) external;

    /**
     * @notice Update an investor's jurisdiction and/or category
     * @param _investor Investor wallet address
     * @param _newJurisdiction New jurisdiction code (bytes32(0) to keep current)
     * @param _newCategory New investor category (bytes32(0) to keep current)
     */
    function updateInvestor(address _investor, bytes32 _newJurisdiction, bytes32 _newCategory) external;

    /**
     * @notice Remove an investor from the registry
     * @param _investor Investor wallet address
     */
    function removeInvestor(address _investor) external;

    // --- Compliance Checks ---

    /**
     * @notice Check if a transfer between two investors is jurisdiction-compliant
     * @param _from Sender address
     * @param _to Receiver address
     * @return compliant True if the transfer is compliant
     */
    function isTransferCompliant(address _from, address _to) external view returns (bool compliant);

    /**
     * @notice Check if a sender can initiate transfers
     * @param _from Sender address
     * @return compliant True if the sender is registered
     */
    function isTransferFromCompliant(address _from) external view returns (bool compliant);

    /**
     * @notice Check if a receiver can receive transfers
     * @param _to Receiver address
     * @return compliant True if the receiver is registered
     */
    function isTransferToCompliant(address _to) external view returns (bool compliant);

    // --- Jurisdiction Configuration ---

    /**
     * @notice Allow or block transfers between two jurisdictions
     * @param _fromJurisdiction Source jurisdiction
     * @param _toJurisdiction Destination jurisdiction
     * @param _allowed Whether transfers are allowed
     */
    function setAllowedTransfer(bytes32 _fromJurisdiction, bytes32 _toJurisdiction, bool _allowed) external;

    /**
     * @notice Set whether same-jurisdiction transfers are allowed by default
     * @param _allowed Default setting
     */
    function setSameJurisdictionDefault(bool _allowed) external;

    /**
     * @notice Allow or block transfers between two investor categories
     * @param _fromCategory Source category
     * @param _toCategory Destination category
     * @param _allowed Whether transfers are allowed
     */
    function setAllowedCategoryTransfer(bytes32 _fromCategory, bytes32 _toCategory, bool _allowed) external;

    // --- View Functions ---

    /**
     * @notice Get an investor's registration details
     * @param _investor Investor address
     * @return jurisdiction Jurisdiction code
     * @return category Investor category
     * @return registered Whether registered
     */
    function getInvestor(address _investor) external view returns (
        bytes32 jurisdiction,
        bytes32 category,
        bool registered
    );

    /**
     * @notice Get total number of registered investors
     * @return count Number of investors
     */
    function getInvestorCount() external view returns (uint256 count);

    /**
     * @notice Check if a jurisdiction pair is allowed
     */
    function isJurisdictionTransferAllowed(bytes32 _fromJurisdiction, bytes32 _toJurisdiction) external view returns (bool allowed);

    /**
     * @notice Check if a category pair is allowed
     */
    function isCategoryTransferAllowed(bytes32 _fromCategory, bytes32 _toCategory) external view returns (bool allowed);
}
