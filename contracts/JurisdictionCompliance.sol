// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IJurisdictionCompliance.sol";

/**
 * @title JurisdictionCompliance
 * @dev Jurisdiction-aware transfer restriction module for RWA tokens.
 *      Blocks transfers between incompatible jurisdictions (e.g. US accredited vs EU MiFID).
 * @author BountyClaw
 */
contract JurisdictionCompliance is IJurisdictionCompliance, Ownable {

    // --- Data Structures ---

    /// @notice Supported jurisdiction codes (e.g. "US", "EU", "SG", "UK")
    bytes32 public constant JURISDICTION_US = keccak256("US");
    bytes32 public constant JURISDICTION_EU = keccak256("EU");
    bytes32 public constant JURISDICTION_UK = keccak256("UK");
    bytes32 public constant JURISDICTION_SG = keccak256("SG");
    bytes32 public constant JURISDICTION_CH = keccak256("CH");
    bytes32 public constant JURISDICTION_JP = keccak256("JP");
    bytes32 public constant JURISDICTION_HK = keccak256("HK");
    bytes32 public constant JURISDICTION_AU = keccak256("AU");

    /// @notice Maps an investor address to their registered jurisdiction code
    mapping(address => bytes32) public investorJurisdiction;

    /// @notice Maps an investor address to their accreditation status (e.g. "accredited", "retail", "qualified")
    mapping(address => bytes32) public investorCategory;

    /// @notice Whether a jurisdiction pair is allowed for transfers.
    ///         fromJurisdiction => toJurisdiction => allowed
    mapping(bytes32 => mapping(bytes32 => bool)) public allowedTransfers;

    /// @notice Whether a specific category can send to another category within the same jurisdiction
    ///         fromCategory => toCategory => allowed
    mapping(bytes32 => mapping(bytes32 => bool)) public allowedCategoryTransfers;

    /// @notice Whether same-jurisdiction transfers are allowed by default
    bool public sameJurisdictionAllowedByDefault;

    /// @notice Array of registered investors (for enumeration)
    address[] public investors;
    mapping(address => bool) public isInvestor;

    // --- Constructor ---

    constructor(address initialOwner) Ownable(initialOwner) {
        sameJurisdictionAllowedByDefault = true;

        // Default: allow transfers within the same jurisdiction
        // Cross-jurisdiction transfers must be explicitly allowed

        // Allow US<->EU transfers (common for RWA tokens)
        _setAllowedTransfer(JURISDICTION_US, JURISDICTION_EU, true);
        _setAllowedTransfer(JURISDICTION_EU, JURISDICTION_US, true);

        // Allow UK<->EU transfers
        _setAllowedTransfer(JURISDICTION_UK, JURISDICTION_EU, true);
        _setAllowedTransfer(JURISDICTION_EU, JURISDICTION_UK, true);

        // Allow US<->UK transfers
        _setAllowedTransfer(JURISDICTION_US, JURISDICTION_UK, true);
        _setAllowedTransfer(JURISDICTION_UK, JURISDICTION_US, true);

        // Allow SG transfers (open jurisdiction for RWA)
        _setAllowedTransfer(JURISDICTION_SG, JURISDICTION_US, true);
        _setAllowedTransfer(JURISDICTION_US, JURISDICTION_SG, true);
        _setAllowedTransfer(JURISDICTION_SG, JURISDICTION_EU, true);
        _setAllowedTransfer(JURISDICTION_EU, JURISDICTION_SG, true);
        _setAllowedTransfer(JURISDICTION_SG, JURISDICTION_UK, true);
        _setAllowedTransfer(JURISDICTION_UK, JURISDICTION_SG, true);

        // Default category transfers
        _setAllowedCategoryTransfer("accredited", "accredited", true);
        _setAllowedCategoryTransfer("accredited", "qualified", true);
        _setAllowedCategoryTransfer("qualified", "accredited", true);
        _setAllowedCategoryTransfer("qualified", "qualified", true);
        _setAllowedCategoryTransfer("retail", "retail", true);
    }

    // --- Modifiers ---

    modifier onlyRegistered(address _investor) {
        require(isInvestor[_investor], "Investor not registered");
        _;
    }

    // --- External Functions ---

    /**
     * @notice Register a new investor with jurisdiction and category
     * @param _investor Investor wallet address
     * @param _jurisdiction Jurisdiction code (e.g. JURISDICTION_US)
     * @param _category Investor category (e.g. "accredited", "retail", "qualified")
     */
    function registerInvestor(
        address _investor,
        bytes32 _jurisdiction,
        bytes32 _category
    ) external onlyOwner {
        require(_investor != address(0), "Invalid address");
        require(_jurisdiction != bytes32(0), "Invalid jurisdiction");
        require(_category != bytes32(0), "Invalid category");
        require(!isInvestor[_investor], "Already registered");

        investorJurisdiction[_investor] = _jurisdiction;
        investorCategory[_investor] = _category;
        isInvestor[_investor] = true;
        investors.push(_investor);

        emit InvestorRegistered(_investor, _jurisdiction, _category);
    }

    /**
     * @notice Update an investor's jurisdiction and/or category
     * @param _investor Investor wallet address
     * @param _newJurisdiction New jurisdiction code
     * @param _newCategory New investor category
     */
    function updateInvestor(
        address _investor,
        bytes32 _newJurisdiction,
        bytes32 _newCategory
    ) external onlyOwner onlyRegistered(_investor) {
        bytes32 oldJurisdiction = investorJurisdiction[_investor];
        bytes32 oldCategory = investorCategory[_investor];

        if (_newJurisdiction != bytes32(0)) {
            investorJurisdiction[_investor] = _newJurisdiction;
        }
        if (_newCategory != bytes32(0)) {
            investorCategory[_investor] = _newCategory;
        }

        emit InvestorUpdated(
            _investor,
            oldJurisdiction,
            investorJurisdiction[_investor],
            oldCategory,
            investorCategory[_investor]
        );
    }

    /**
     * @notice Remove an investor from the registry
     * @param _investor Investor wallet address
     */
    function removeInvestor(address _investor) external onlyOwner onlyRegistered(_investor) {
        investorJurisdiction[_investor] = bytes32(0);
        investorCategory[_investor] = bytes32(0);
        isInvestor[_investor] = false;

        // Remove from array (swap and pop)
        for (uint256 i = 0; i < investors.length; i++) {
            if (investors[i] == _investor) {
                investors[i] = investors[investors.length - 1];
                investors.pop();
                break;
            }
        }

        emit InvestorRemoved(_investor);
    }

    /**
     * @notice Check if a transfer between two investors is compliant
     * @param _from Sender address
     * @param _to Receiver address
     * @return compliant True if the transfer is jurisdiction-compliant
     */
    function isTransferCompliant(address _from, address _to) external view returns (bool compliant) {
        require(isInvestor[_from], "Sender not registered");
        require(isInvestor[_to], "Receiver not registered");

        bytes32 fromJurisdiction = investorJurisdiction[_from];
        bytes32 toJurisdiction = investorJurisdiction[_to];
        bytes32 fromCategory = investorCategory[_from];
        bytes32 toCategory = investorCategory[_to];

        // Check jurisdiction compatibility
        if (!_isJurisdictionAllowed(fromJurisdiction, toJurisdiction)) {
            return false;
        }

        // Check category compatibility
        if (!_isCategoryAllowed(fromCategory, toCategory)) {
            return false;
        }

        return true;
    }

    /**
     * @notice Check if a transfer from an address is compliant (sender side)
     * @param _from Sender address
     * @return compliant True if the sender can initiate transfers
     */
    function isTransferFromCompliant(address _from) external view returns (bool compliant) {
        return isInvestor[_from];
    }

    /**
     * @notice Check if a transfer to an address is compliant (receiver side)
     * @param _to Receiver address
     * @return compliant True if the receiver can receive transfers
     */
    function isTransferToCompliant(address _to) external view returns (bool compliant) {
        return isInvestor[_to];
    }

    // --- Jurisdiction Configuration ---

    /**
     * @notice Allow or block transfers between two jurisdictions
     * @param _fromJurisdiction Source jurisdiction
     * @param _toJurisdiction Destination jurisdiction
     * @param _allowed Whether transfers are allowed
     */
    function setAllowedTransfer(
        bytes32 _fromJurisdiction,
        bytes32 _toJurisdiction,
        bool _allowed
    ) external onlyOwner {
        _setAllowedTransfer(_fromJurisdiction, _toJurisdiction, _allowed);

        if (_allowed) {
            emit TransferAllowed(_fromJurisdiction, _toJurisdiction);
        } else {
            emit TransferBlocked(_fromJurisdiction, _toJurisdiction);
        }
    }

    /**
     * @notice Set whether same-jurisdiction transfers are allowed by default
     * @param _allowed Default setting for same-jurisdiction transfers
     */
    function setSameJurisdictionDefault(bool _allowed) external onlyOwner {
        sameJurisdictionAllowedByDefault = _allowed;
    }

    /**
     * @notice Allow or block transfers between two investor categories
     * @param _fromCategory Source category
     * @param _toCategory Destination category
     * @param _allowed Whether transfers are allowed
     */
    function setAllowedCategoryTransfer(
        bytes32 _fromCategory,
        bytes32 _toCategory,
        bool _allowed
    ) external onlyOwner {
        _setAllowedCategoryTransfer(_fromCategory, _toCategory, _allowed);

        if (_allowed) {
            emit CategoryTransferAllowed(_fromCategory, _toCategory);
        } else {
            emit CategoryTransferBlocked(_fromCategory, _toCategory);
        }
    }

    // --- View Functions ---

    /**
     * @notice Get an investor's full registration details
     * @param _investor Investor address
     * @return jurisdiction The investor's jurisdiction code
     * @return category The investor's category
     * @return registered Whether the investor is registered
     */
    function getInvestor(address _investor) external view returns (
        bytes32 jurisdiction,
        bytes32 category,
        bool registered
    ) {
        return (
            investorJurisdiction[_investor],
            investorCategory[_investor],
            isInvestor[_investor]
        );
    }

    /**
     * @notice Get total number of registered investors
     * @return count Number of investors
     */
    function getInvestorCount() external view returns (uint256 count) {
        return investors.length;
    }

    /**
     * @notice Check if a jurisdiction pair is allowed
     * @param _fromJurisdiction Source jurisdiction
     * @param _toJurisdiction Destination jurisdiction
     * @return allowed Whether transfers are allowed
     */
    function isJurisdictionTransferAllowed(
        bytes32 _fromJurisdiction,
        bytes32 _toJurisdiction
    ) external view returns (bool allowed) {
        return _isJurisdictionAllowed(_fromJurisdiction, _toJurisdiction);
    }

    /**
     * @notice Check if a category pair is allowed
     * @param _fromCategory Source category
     * @param _toCategory Destination category
     * @return allowed Whether transfers are allowed
     */
    function isCategoryTransferAllowed(
        bytes32 _fromCategory,
        bytes32 _toCategory
    ) external view returns (bool allowed) {
        return _isCategoryAllowed(_fromCategory, _toCategory);
    }

    // --- Internal Functions ---

    function _setAllowedTransfer(
        bytes32 _fromJurisdiction,
        bytes32 _toJurisdiction,
        bool _allowed
    ) internal {
        allowedTransfers[_fromJurisdiction][_toJurisdiction] = _allowed;
    }

    function _setAllowedCategoryTransfer(
        bytes32 _fromCategory,
        bytes32 _toCategory,
        bool _allowed
    ) internal {
        allowedCategoryTransfers[_fromCategory][_toCategory] = _allowed;
    }

    function _isJurisdictionAllowed(
        bytes32 _fromJurisdiction,
        bytes32 _toJurisdiction
    ) internal view returns (bool) {
        // Same jurisdiction: use default setting
        if (_fromJurisdiction == _toJurisdiction) {
            return sameJurisdictionAllowedByDefault;
        }

        // Cross-jurisdiction: check explicit mapping
        return allowedTransfers[_fromJurisdiction][_toJurisdiction];
    }

    function _isCategoryAllowed(
        bytes32 _fromCategory,
        bytes32 _toCategory
    ) internal view returns (bool) {
        // Same category: always allowed
        if (_fromCategory == _toCategory) {
            return true;
        }

        // Cross-category: check explicit mapping
        return allowedCategoryTransfers[_fromCategory][_toCategory];
    }
}
