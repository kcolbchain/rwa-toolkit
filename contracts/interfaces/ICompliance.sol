// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ICompliance
/// @notice Interface for compliance modules as defined by ERC-3643 / T-REX.
///         Enforces transfer restrictions such as investor caps, per-wallet limits,
///         and country-level restrictions.
interface ICompliance {
    // ──────────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────────

    event MaxInvestorCountSet(uint256 max);
    event MaxBalancePerInvestorSet(uint256 max);
    event CountryRestricted(uint16 indexed country);
    event CountryUnrestricted(uint16 indexed country);
    event TokenBound(address indexed token);

    // ──────────────────────────────────────────────
    //  Configuration
    // ──────────────────────────────────────────────

    /// @notice Bind this compliance module to a specific token contract.
    function bindToken(address token) external;

    /// @notice Set the maximum number of distinct token holders.
    function setMaxInvestorCount(uint256 max) external;

    /// @notice Set the maximum token balance any single investor may hold.
    function setMaxBalancePerInvestor(uint256 max) external;

    /// @notice Restrict transfers to/from a specific country.
    function addCountryRestriction(uint16 country) external;

    /// @notice Remove a country restriction.
    function removeCountryRestriction(uint16 country) external;

    // ──────────────────────────────────────────────
    //  Transfer checks
    // ──────────────────────────────────────────────

    /// @notice Return `true` if the transfer is compliant.
    function canTransfer(address from, address to, uint256 amount) external view returns (bool);

    /// @notice Hook called **after** a compliant transfer has been executed.
    function transferred(address from, address to, uint256 amount) external;

    /// @notice Hook called **after** new tokens are minted.
    function created(address to, uint256 amount) external;

    /// @notice Hook called **after** tokens are burned.
    function destroyed(address from, uint256 amount) external;

    // ──────────────────────────────────────────────
    //  View helpers
    // ──────────────────────────────────────────────

    /// @notice Check whether a country is restricted.
    function isCountryRestricted(uint16 country) external view returns (bool);

    /// @notice Return the current investor count tracked by this module.
    function investorCount() external view returns (uint256);
}
