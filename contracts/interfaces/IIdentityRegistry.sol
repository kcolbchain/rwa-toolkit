// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IIdentityRegistry
/// @notice Interface for the Identity Registry as defined by ERC-3643 / T-REX.
///         Manages investor identities, country codes, and accreditation status.
interface IIdentityRegistry {
    // ──────────────────────────────────────────────
    //  Events
    // ──────────────────────────────────────────────

    event IdentityRegistered(address indexed investor, uint16 indexed country);
    event IdentityRemoved(address indexed investor);
    event IdentityUpdated(address indexed investor, uint16 indexed country);
    event CountryUpdated(address indexed investor, uint16 indexed country);
    event AccreditationUpdated(address indexed investor, bool accredited);

    // ──────────────────────────────────────────────
    //  Identity management
    // ──────────────────────────────────────────────

    /// @notice Register a new investor identity.
    /// @param investor  The investor wallet address.
    /// @param country   ISO-3166-1 numeric country code.
    function registerIdentity(address investor, uint16 country) external;

    /// @notice Remove an investor identity.
    function removeIdentity(address investor) external;

    /// @notice Update the country code for an investor.
    function updateCountry(address investor, uint16 country) external;

    /// @notice Set accreditation / KYC status for an investor.
    function setAccreditation(address investor, bool accredited) external;

    // ──────────────────────────────────────────────
    //  View helpers
    // ──────────────────────────────────────────────

    /// @notice Check whether `investor` has a registered, verified identity.
    function isVerified(address investor) external view returns (bool);

    /// @notice Return the country code for `investor`.
    function investorCountry(address investor) external view returns (uint16);

    /// @notice Return the accreditation status for `investor`.
    function isAccredited(address investor) external view returns (bool);

    /// @notice Check if an identity is registered (may not yet be accredited).
    function hasIdentity(address investor) external view returns (bool);
}
