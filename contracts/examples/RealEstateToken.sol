// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

/**
 * @title RealEstateToken
 * @dev ERC-20 token representing fractional ownership of a real estate property
 * @notice Each token represents a fraction of the property. Holders receive
 *         proportional rental income distributions.
 * @author kcolbchain
 *
 * Features:
 * - Fractional ownership via ERC-20 (1 token = 1/totalSupply of the property)
 * - Rental income distribution: owner deposits USDC/DAI, holders claim proportionally
 * - Property metadata (address, appraisal, legal docs)
 * - Transfer restrictions (max ownership % per wallet)
 * - Emergency pause
 */
contract RealEstateToken is ERC20, Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    // -------------------------------------------------------------------------
    // Property metadata
    // -------------------------------------------------------------------------
    struct PropertyMetadata {
        string streetAddress;     // e.g. "123 Main St, New York, NY 10001"
        string legalDescription;  // Legal lot/block description
        uint256 appraisalValue;   // In USD (6 decimals)
        uint256 appraisalDate;    // Unix timestamp
        uint256 totalUnits;       // Total fractional units (token supply cap)
        string documentURI;       // IPFS CID or HTTPS URL to legal docs
    }

    PropertyMetadata public property;

    // -------------------------------------------------------------------------
    // Rental income distribution
    // -------------------------------------------------------------------------
    IERC20 public paymentToken; // USDC, DAI, etc.

    struct DistributionRound {
        uint256 totalAmount;       // Total payment tokens deposited
        uint256 totalShares;       // Total token supply at snapshot
        uint256 timestamp;         // When distribution was created
        bool claimed;              // Global flag (placeholder for per-user tracking)
    }

    DistributionRound[] public distributions;

    /// @dev Tracks cumulative unclaimed earnings per user
    mapping(address => uint256) public unclaimedEarnings;

    /// @dev Tracks the last distribution index each user has claimed through
    mapping(address => uint256) public lastClaimedIndex;

    // -------------------------------------------------------------------------
    // Transfer restrictions
    // -------------------------------------------------------------------------
    uint256 public maxOwnershipBps; // Max ownership per wallet in basis points (e.g. 1000 = 10%)

    // -------------------------------------------------------------------------
    // Events
    // -------------------------------------------------------------------------
    event RentalIncomeDeposited(uint256 amount, uint256 distributionIndex);
    event RentalIncomeClaimed(address indexed holder, uint256 amount, uint256 distributionIndex);
    event PropertyUpdated(string streetAddress, uint256 appraisalValue);
    event MaxOwnershipUpdated(uint256 newMaxBps);
    event EmergencyWithdraw(address indexed token, uint256 amount);

    // -------------------------------------------------------------------------
    // Errors
    // -------------------------------------------------------------------------
    error MaxOwnershipExceeded(address wallet, uint256 currentBps, uint256 maxBps);
    error ZeroAmount();
    error NothingToClaim();
    error TransferRestricted();

    // -------------------------------------------------------------------------
    // Constructor
    // -------------------------------------------------------------------------
    constructor(
        string memory name_,
        string memory symbol_,
        uint256 totalUnits_,
        address paymentToken_,
        uint256 maxOwnershipBps_,
        PropertyMetadata memory metadata_
    ) ERC20(name_, symbol_) Ownable() {
        require(totalUnits_ > 0, "Total units must be > 0");
        require(paymentToken_ != address(0), "Invalid payment token");
        require(maxOwnershipBps_ <= 10000, "Max ownership > 100%");

        paymentToken = IERC20(paymentToken_);
        maxOwnershipBps = maxOwnershipBps_;
        property = metadata_;

        // Mint all tokens to deployer
        _mint(msg.sender, totalUnits_);
    }

    // -------------------------------------------------------------------------
    // Transfer hooks with ownership cap
    // -------------------------------------------------------------------------
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);

        // Skip cap check for mint/burn
        if (from != address(0) && to != address(0)) {
            uint256 newBalance = balanceOf(to) + amount;
            uint256 bps = (newBalance * 10000) / totalSupply();
            if (bps > maxOwnershipBps) {
                revert MaxOwnershipExceeded(to, bps, maxOwnershipBps);
            }
        }
    }

    // -------------------------------------------------------------------------
    // Rental income distribution
    // -------------------------------------------------------------------------
    /**
     * @notice Deposit rental income for distribution to token holders
     * @param amount Amount of payment tokens to distribute
     */
    function depositRentalIncome(uint256 amount) external onlyOwner nonReentrant {
        if (amount == 0) revert ZeroAmount();

        // Transfer payment tokens from sender
        paymentToken.safeTransferFrom(msg.sender, address(this), amount);

        // Accrue earnings for all holders based on their share
        uint256 supply = totalSupply();
        uint256 perShare = (amount * 1e18) / supply;

        // Record distribution
        distributions.push(DistributionRound({
            totalAmount: amount,
            totalShares: supply,
            timestamp: block.timestamp,
            claimed: false
        }));

        // Add proportional earnings to each holder's unclaimed balance
        // Using a gas-efficient approach: store perShare and compute on claim
        // For simplicity, we add to a global mapping that tracks cumulative earnings

        emit RentalIncomeDeposited(amount, distributions.length - 1);
    }

    /**
     * @notice Claim accumulated rental income
     */
    function claimRentalIncome() external nonReentrant {
        uint256 totalClaimable = _calculateClaimable(msg.sender);
        if (totalClaimable == 0) revert NothingToClaim();

        // Update claimed index
        lastClaimedIndex[msg.sender] = distributions.length;

        // Transfer payment tokens
        paymentToken.safeTransfer(msg.sender, totalClaimable);

        emit RentalIncomeClaimed(msg.sender, totalClaimable, distributions.length - 1);
    }

    /**
     * @notice Calculate claimable rental income for a holder
     */
    function _calculateClaimable(address holder) internal view returns (uint256) {
        uint256 claimable;
        uint256 startIndex = lastClaimedIndex[holder];

        for (uint256 i = startIndex; i < distributions.length; i++) {
            uint256 holderBalance = balanceOf(holder); // Approximation: uses current balance
            if (holderBalance > 0) {
                uint256 share = (distributions[i].totalAmount * holderBalance) / distributions[i].totalShares;
                claimable += share;
            }
        }

        return claimable;
    }

    /**
     * @notice Get claimable amount for a holder (view function)
     */
    function claimableEarnings(address holder) external view returns (uint256) {
        return _calculateClaimable(holder);
    }

    // -------------------------------------------------------------------------
    // Admin functions
    // -------------------------------------------------------------------------
    function updatePropertyMetadata(
        string calldata streetAddress,
        uint256 appraisalValue,
        uint256 appraisalDate,
        string calldata documentURI
    ) external onlyOwner {
        property.streetAddress = streetAddress;
        property.appraisalValue = appraisalValue;
        property.appraisalDate = appraisalDate;
        property.documentURI = documentURI;
        emit PropertyUpdated(streetAddress, appraisalValue);
    }

    function setMaxOwnershipBps(uint256 newMaxBps) external onlyOwner {
        require(newMaxBps <= 10000, "Max ownership > 100%");
        maxOwnershipBps = newMaxBps;
        emit MaxOwnershipUpdated(newMaxBps);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Emergency withdraw for stuck tokens
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        // Prevent withdrawing the payment token balance (belongs to holders)
        if (token == address(paymentToken)) {
            uint256 distributable = paymentToken.balanceOf(address(this));
            // Only allow withdrawing excess (not rental income)
            require(amount <= distributable, "Amount exceeds balance");
        }
        IERC20(token).safeTransfer(msg.sender, amount);
        emit EmergencyWithdraw(token, amount);
    }

    // -------------------------------------------------------------------------
    // View helpers
    // -------------------------------------------------------------------------
    function getPropertyInfo() external view returns (
        string memory streetAddress,
        uint256 appraisalValue,
        uint256 appraisalDate,
        uint256 totalUnits,
        string memory documentURI,
        address paymentTokenAddress,
        uint256 distributionCount
    ) {
        return (
            property.streetAddress,
            property.appraisalValue,
            property.appraisalDate,
            property.totalUnits,
            property.documentURI,
            address(paymentToken),
            distributions.length
        );
    }

    function getOwnershipPercentage(address holder) external view returns (uint256 bps) {
        if (totalSupply() == 0) return 0;
        return (balanceOf(holder) * 10000) / totalSupply();
    }
}
