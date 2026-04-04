// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICompliance} from "../interfaces/ICompliance.sol";
import {IIdentityRegistry} from "../interfaces/IIdentityRegistry.sol";

/// @title BasicCompliance
/// @notice Basic compliance module implementing the ERC-3643 / T-REX compliance
///         interface.  Enforces:
///         • Maximum investor count
///         • Maximum token balance per investor
///         • Country-level transfer restrictions
///         • Identity verification requirement (via bound IdentityRegistry)
contract BasicCompliance is ICompliance {
    // ──────────────────────────────────────────────
    //  State
    // ──────────────────────────────────────────────

    address public owner;
    address public boundToken;
    IIdentityRegistry public identityRegistry;

    uint256 public maxInvestors;
    uint256 public maxBalancePerInvestor;

    uint256 private _investorCount;

    mapping(uint16 => bool) private _restrictedCountries;
    mapping(address => uint256) private _balances; // shadow balances for compliance tracking
    mapping(address => bool) private _isHolder; // true if address currently holds tokens

    // ──────────────────────────────────────────────
    //  Modifiers
    // ──────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "BasicCompliance: caller is not owner");
        _;
    }

    modifier onlyToken() {
        require(msg.sender == boundToken, "BasicCompliance: caller is not the token");
        _;
    }

    // ──────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────

    /// @param registry_  Address of the IdentityRegistry contract.
    constructor(address registry_) {
        require(registry_ != address(0), "BasicCompliance: zero registry");
        owner = msg.sender;
        identityRegistry = IIdentityRegistry(registry_);
    }

    // ──────────────────────────────────────────────
    //  Configuration (owner-only)
    // ──────────────────────────────────────────────

    /// @inheritdoc ICompliance
    function bindToken(address token) external onlyOwner {
        require(token != address(0), "BasicCompliance: zero token");
        boundToken = token;
        emit TokenBound(token);
    }

    /// @inheritdoc ICompliance
    function setMaxInvestorCount(uint256 max) external onlyOwner {
        maxInvestors = max;
        emit MaxInvestorCountSet(max);
    }

    /// @inheritdoc ICompliance
    function setMaxBalancePerInvestor(uint256 max) external onlyOwner {
        maxBalancePerInvestor = max;
        emit MaxBalancePerInvestorSet(max);
    }

    /// @inheritdoc ICompliance
    function addCountryRestriction(uint16 country) external onlyOwner {
        _restrictedCountries[country] = true;
        emit CountryRestricted(country);
    }

    /// @inheritdoc ICompliance
    function removeCountryRestriction(uint16 country) external onlyOwner {
        _restrictedCountries[country] = false;
        emit CountryUnrestricted(country);
    }

    // ──────────────────────────────────────────────
    //  Transfer checks
    // ──────────────────────────────────────────────

    /// @inheritdoc ICompliance
    function canTransfer(address from, address to, uint256 amount) external view returns (bool) {
        // Both parties must be verified
        if (!identityRegistry.isVerified(from)) return false;
        if (!identityRegistry.isVerified(to)) return false;

        // Country restrictions
        if (_restrictedCountries[identityRegistry.investorCountry(from)]) return false;
        if (_restrictedCountries[identityRegistry.investorCountry(to)]) return false;

        // Max balance per investor
        if (maxBalancePerInvestor > 0 && _balances[to] + amount > maxBalancePerInvestor) {
            return false;
        }

        // Max investor count — only matters if `to` is a new holder
        if (maxInvestors > 0 && !_isHolder[to] && _investorCount >= maxInvestors) {
            return false;
        }

        return true;
    }

    /// @inheritdoc ICompliance
    function transferred(address from, address to, uint256 amount) external onlyToken {
        _balances[from] -= amount;
        _balances[to] += amount;

        // Track holder count
        if (!_isHolder[to] && _balances[to] > 0) {
            _isHolder[to] = true;
            _investorCount++;
        }
        if (_isHolder[from] && _balances[from] == 0) {
            _isHolder[from] = false;
            _investorCount--;
        }
    }

    /// @inheritdoc ICompliance
    function created(address to, uint256 amount) external onlyToken {
        _balances[to] += amount;
        if (!_isHolder[to]) {
            _isHolder[to] = true;
            _investorCount++;
        }
    }

    /// @inheritdoc ICompliance
    function destroyed(address from, uint256 amount) external onlyToken {
        _balances[from] -= amount;
        if (_isHolder[from] && _balances[from] == 0) {
            _isHolder[from] = false;
            _investorCount--;
        }
    }

    // ──────────────────────────────────────────────
    //  View helpers
    // ──────────────────────────────────────────────

    /// @inheritdoc ICompliance
    function isCountryRestricted(uint16 country) external view returns (bool) {
        return _restrictedCountries[country];
    }

    /// @inheritdoc ICompliance
    function investorCount() external view returns (uint256) {
        return _investorCount;
    }
}
