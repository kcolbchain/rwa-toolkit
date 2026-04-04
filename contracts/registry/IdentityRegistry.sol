// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IIdentityRegistry} from "../interfaces/IIdentityRegistry.sol";

/// @title IdentityRegistry
/// @notice Stub implementation of the T-REX / ERC-3643 Identity Registry.
///         Manages investor identity registration, country codes, and
///         accreditation (KYC/AML) status.  Designed to be extended with
///         on-chain identity (ERC-735/ERC-734) or off-chain oracle bridges.
contract IdentityRegistry is IIdentityRegistry {
    // ──────────────────────────────────────────────
    //  Types
    // ──────────────────────────────────────────────

    struct Identity {
        uint16 country; // ISO-3166-1 numeric
        bool registered;
        bool accredited; // KYC/AML cleared
    }

    // ──────────────────────────────────────────────
    //  State
    // ──────────────────────────────────────────────

    address public owner;
    mapping(address => Identity) private _identities;

    // ──────────────────────────────────────────────
    //  Modifiers
    // ──────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "IdentityRegistry: caller is not owner");
        _;
    }

    // ──────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────

    constructor() {
        owner = msg.sender;
    }

    // ──────────────────────────────────────────────
    //  Identity management
    // ──────────────────────────────────────────────

    /// @inheritdoc IIdentityRegistry
    function registerIdentity(address investor, uint16 country) external onlyOwner {
        require(investor != address(0), "IdentityRegistry: zero address");
        require(!_identities[investor].registered, "IdentityRegistry: already registered");

        _identities[investor] = Identity({country: country, registered: true, accredited: false});

        emit IdentityRegistered(investor, country);
    }

    /// @inheritdoc IIdentityRegistry
    function removeIdentity(address investor) external onlyOwner {
        require(_identities[investor].registered, "IdentityRegistry: not registered");

        delete _identities[investor];

        emit IdentityRemoved(investor);
    }

    /// @inheritdoc IIdentityRegistry
    function updateCountry(address investor, uint16 country) external onlyOwner {
        require(_identities[investor].registered, "IdentityRegistry: not registered");

        _identities[investor].country = country;

        emit CountryUpdated(investor, country);
    }

    /// @inheritdoc IIdentityRegistry
    function setAccreditation(address investor, bool accredited) external onlyOwner {
        require(_identities[investor].registered, "IdentityRegistry: not registered");

        _identities[investor].accredited = accredited;

        emit AccreditationUpdated(investor, accredited);
    }

    // ──────────────────────────────────────────────
    //  View helpers
    // ──────────────────────────────────────────────

    /// @inheritdoc IIdentityRegistry
    function isVerified(address investor) external view returns (bool) {
        Identity storage id_ = _identities[investor];
        return id_.registered && id_.accredited;
    }

    /// @inheritdoc IIdentityRegistry
    function investorCountry(address investor) external view returns (uint16) {
        return _identities[investor].country;
    }

    /// @inheritdoc IIdentityRegistry
    function isAccredited(address investor) external view returns (bool) {
        return _identities[investor].accredited;
    }

    /// @inheritdoc IIdentityRegistry
    function hasIdentity(address investor) external view returns (bool) {
        return _identities[investor].registered;
    }
}
