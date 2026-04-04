// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IIdentityRegistry} from "./IIdentityRegistry.sol";
import {ICompliance} from "./ICompliance.sol";

/// @title IToken
/// @notice Interface for an ERC-3643 / T-REX compliant security token.
///         Extends ERC-20 with identity verification, compliance hooks,
///         pause / freeze / recovery capabilities.
interface IToken {
    // ──────────────────────────────────────────────
    //  Events  (ERC-20 events are inherited by implementation)
    // ──────────────────────────────────────────────

    event Paused(address indexed account);
    event Unpaused(address indexed account);
    event AddressFrozen(address indexed investor, bool indexed frozen);
    event TokensRecovered(address indexed from, address indexed to, uint256 amount);
    event IdentityRegistrySet(address indexed registry);
    event ComplianceSet(address indexed compliance);

    // ──────────────────────────────────────────────
    //  Token lifecycle
    // ──────────────────────────────────────────────

    /// @notice Mint new tokens to a verified investor.
    function mint(address to, uint256 amount) external;

    /// @notice Burn tokens from a verified investor.
    function burn(address from, uint256 amount) external;

    // ──────────────────────────────────────────────
    //  Pause / Freeze / Recover
    // ──────────────────────────────────────────────

    /// @notice Pause all token transfers.
    function pause() external;

    /// @notice Unpause token transfers.
    function unpause() external;

    /// @notice Freeze or unfreeze a specific investor address.
    function setAddressFrozen(address investor, bool frozen) external;

    /// @notice Recover tokens from a frozen address (e.g. lost keys).
    function recoveryTransfer(address from, address to, uint256 amount) external;

    // ──────────────────────────────────────────────
    //  Registry / Compliance setters
    // ──────────────────────────────────────────────

    /// @notice Set the identity registry contract.
    function setIdentityRegistry(IIdentityRegistry registry) external;

    /// @notice Set the compliance module contract.
    function setCompliance(ICompliance compliance) external;

    // ──────────────────────────────────────────────
    //  View helpers
    // ──────────────────────────────────────────────

    /// @notice Whether the token is currently paused.
    function paused() external view returns (bool);

    /// @notice Whether `investor` is frozen.
    function isFrozen(address investor) external view returns (bool);

    /// @notice The identity registry bound to this token.
    function identityRegistry() external view returns (IIdentityRegistry);

    /// @notice The compliance module bound to this token.
    function compliance() external view returns (ICompliance);
}
