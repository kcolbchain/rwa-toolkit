// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IToken} from "../interfaces/IToken.sol";
import {IIdentityRegistry} from "../interfaces/IIdentityRegistry.sol";
import {ICompliance} from "../interfaces/ICompliance.sol";

/// @title ERC3643Token
/// @notice ERC-20 compatible security token implementing the ERC-3643 / T-REX
///         standard.  Every transfer is gated by:
///           1. Identity verification (via IdentityRegistry)
///           2. Compliance rules (via a pluggable Compliance module)
///         The token is pausable, individual addresses can be frozen, and an
///         owner can perform recovery transfers from frozen addresses.
contract ERC3643Token is IToken {
    // ──────────────────────────────────────────────
    //  ERC-20 storage
    // ──────────────────────────────────────────────

    string public name;
    string public symbol;
    uint8 public constant decimals = 18;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    // ──────────────────────────────────────────────
    //  ERC-20 events
    // ──────────────────────────────────────────────

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // ──────────────────────────────────────────────
    //  ERC-3643 state
    // ──────────────────────────────────────────────

    address public owner;
    bool private _paused;
    IIdentityRegistry private _identityRegistry;
    ICompliance private _compliance;
    mapping(address => bool) private _frozen;

    // ──────────────────────────────────────────────
    //  Modifiers
    // ──────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "ERC3643Token: caller is not owner");
        _;
    }

    modifier whenNotPaused() {
        require(!_paused, "ERC3643Token: token is paused");
        _;
    }

    // ──────────────────────────────────────────────
    //  Constructor
    // ──────────────────────────────────────────────

    /// @param name_     Token name.
    /// @param symbol_   Token symbol.
    /// @param registry_ Address of the IdentityRegistry contract.
    /// @param compliance_ Address of the Compliance module contract.
    constructor(string memory name_, string memory symbol_, address registry_, address compliance_) {
        require(registry_ != address(0), "ERC3643Token: zero registry");
        require(compliance_ != address(0), "ERC3643Token: zero compliance");

        name = name_;
        symbol = symbol_;
        owner = msg.sender;
        _identityRegistry = IIdentityRegistry(registry_);
        _compliance = ICompliance(compliance_);
    }

    // ──────────────────────────────────────────────
    //  ERC-20 functions
    // ──────────────────────────────────────────────

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external whenNotPaused returns (bool) {
        _transferChecked(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external whenNotPaused returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "ERC3643Token: insufficient allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transferChecked(from, to, amount);
        return true;
    }

    // ──────────────────────────────────────────────
    //  Token lifecycle (owner-only)
    // ──────────────────────────────────────────────

    /// @inheritdoc IToken
    function mint(address to, uint256 amount) external onlyOwner {
        require(to != address(0), "ERC3643Token: mint to zero address");
        require(_identityRegistry.isVerified(to), "ERC3643Token: recipient not verified");

        totalSupply += amount;
        balanceOf[to] += amount;

        _compliance.created(to, amount);

        emit Transfer(address(0), to, amount);
    }

    /// @inheritdoc IToken
    function burn(address from, uint256 amount) external onlyOwner {
        require(balanceOf[from] >= amount, "ERC3643Token: burn exceeds balance");

        balanceOf[from] -= amount;
        totalSupply -= amount;

        _compliance.destroyed(from, amount);

        emit Transfer(from, address(0), amount);
    }

    // ──────────────────────────────────────────────
    //  Pause / Freeze / Recover (owner-only)
    // ──────────────────────────────────────────────

    /// @inheritdoc IToken
    function pause() external onlyOwner {
        _paused = true;
        emit Paused(msg.sender);
    }

    /// @inheritdoc IToken
    function unpause() external onlyOwner {
        _paused = false;
        emit Unpaused(msg.sender);
    }

    /// @inheritdoc IToken
    function setAddressFrozen(address investor, bool frozen) external onlyOwner {
        _frozen[investor] = frozen;
        emit AddressFrozen(investor, frozen);
    }

    /// @inheritdoc IToken
    function recoveryTransfer(address from, address to, uint256 amount) external onlyOwner {
        require(_frozen[from], "ERC3643Token: source not frozen");
        require(_identityRegistry.isVerified(to), "ERC3643Token: recipient not verified");
        require(balanceOf[from] >= amount, "ERC3643Token: recovery exceeds balance");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        _compliance.transferred(from, to, amount);

        emit Transfer(from, to, amount);
        emit TokensRecovered(from, to, amount);
    }

    // ──────────────────────────────────────────────
    //  Registry / Compliance setters (owner-only)
    // ──────────────────────────────────────────────

    /// @inheritdoc IToken
    function setIdentityRegistry(IIdentityRegistry registry) external onlyOwner {
        require(address(registry) != address(0), "ERC3643Token: zero registry");
        _identityRegistry = registry;
        emit IdentityRegistrySet(address(registry));
    }

    /// @inheritdoc IToken
    function setCompliance(ICompliance compliance_) external onlyOwner {
        require(address(compliance_) != address(0), "ERC3643Token: zero compliance");
        _compliance = compliance_;
        emit ComplianceSet(address(compliance_));
    }

    // ──────────────────────────────────────────────
    //  View helpers
    // ──────────────────────────────────────────────

    /// @inheritdoc IToken
    function paused() external view returns (bool) {
        return _paused;
    }

    /// @inheritdoc IToken
    function isFrozen(address investor) external view returns (bool) {
        return _frozen[investor];
    }

    /// @inheritdoc IToken
    function identityRegistry() external view returns (IIdentityRegistry) {
        return _identityRegistry;
    }

    /// @inheritdoc IToken
    function compliance() external view returns (ICompliance) {
        return _compliance;
    }

    // ──────────────────────────────────────────────
    //  Internal
    // ──────────────────────────────────────────────

    /// @dev Shared transfer logic with identity + compliance checks.
    function _transferChecked(address from, address to, uint256 amount) internal {
        require(to != address(0), "ERC3643Token: transfer to zero address");
        require(!_frozen[from], "ERC3643Token: sender is frozen");
        require(!_frozen[to], "ERC3643Token: recipient is frozen");
        require(_identityRegistry.isVerified(from), "ERC3643Token: sender not verified");
        require(_identityRegistry.isVerified(to), "ERC3643Token: recipient not verified");
        require(_compliance.canTransfer(from, to, amount), "ERC3643Token: transfer not compliant");
        require(balanceOf[from] >= amount, "ERC3643Token: insufficient balance");

        balanceOf[from] -= amount;
        balanceOf[to] += amount;

        _compliance.transferred(from, to, amount);

        emit Transfer(from, to, amount);
    }
}
