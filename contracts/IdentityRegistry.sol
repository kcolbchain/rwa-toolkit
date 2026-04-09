// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IIdentityRegistry.sol";

/**
 * @title IdentityRegistry
 * @dev Implementation of identity registry for ERC-3643 tokens
 * @notice Manages on-chain identity verification for wallet addresses
 * @author BountyClaw
 */
contract IdentityRegistry is IIdentityRegistry, Ownable {
    
    /// @notice Mapping from wallet to identity contract
    mapping(address => address) private _identities;
    
    /// @notice Mapping from identity to verification status
    mapping(address => bool) private _verifiedIdentities;
    
    /// @notice Array of all registered wallets for iteration
    address[] private _registeredWallets;
    
    /// @notice Trusted issuers who can verify identities
    mapping(address => bool) public trustedIssuers;
    
    /// @notice Events
    event TrustedIssuerAdded(address indexed issuer);
    event TrustedIssuerRemoved(address indexed issuer);
    
    /// @notice Custom errors
    error IdentityAlreadyExists(address wallet);
    error IdentityNotFound(address wallet);
    error InvalidIdentity(address identity);
    error NotTrustedIssuer(address issuer);
    error ArraysLengthMismatch();
    
    /**
     * @dev Constructor
     * @param initialOwner Address of the contract owner
     */
    constructor(address initialOwner) Ownable(initialOwner) {}
    
    /**
     * @notice Modifier to restrict to trusted issuers
     */
    modifier onlyTrustedIssuer() {
        require(trustedIssuers[msg.sender] || msg.sender == owner(), "Not trusted issuer");
        _;
    }
    
    /**
     * @notice Add a trusted issuer
     * @param _issuer Address of the trusted issuer
     */
    function addTrustedIssuer(address _issuer) external onlyOwner {
        require(_issuer != address(0), "Invalid issuer address");
        trustedIssuers[_issuer] = true;
        emit TrustedIssuerAdded(_issuer);
    }
    
    /**
     * @notice Remove a trusted issuer
     * @param _issuer Address of the trusted issuer to remove
     */
    function removeTrustedIssuer(address _issuer) external onlyOwner {
        trustedIssuers[_issuer] = false;
        emit TrustedIssuerRemoved(_issuer);
    }
    
    /**
     * @notice Get identity for a wallet
     * @param _wallet The wallet address
     * @return identity The identity contract address
     */
    function getIdentity(address _wallet) external view override returns (address identity) {
        return _identities[_wallet];
    }
    
    /**
     * @notice Check if wallet is verified
     * @param _wallet The wallet address
     * @return verified True if verified
     */
    function isVerified(address _wallet) external view override returns (bool verified) {
        address identity = _identities[_wallet];
        if (identity == address(0)) {
            return false;
        }
        return _verifiedIdentities[identity];
    }
    
    /**
     * @notice Register identity for a wallet
     * @param _wallet The wallet address
     * @param _identity The identity contract address
     */
    function registerIdentity(
        address _wallet,
        address _identity
    ) external override onlyTrustedIssuer {
        require(_wallet != address(0), "Invalid wallet");
        require(_identity != address(0), "Invalid identity");
        require(_identities[_wallet] == address(0), "Identity already exists");
        
        _identities[_wallet] = _identity;
        _verifiedIdentities[_identity] = true;
        _registeredWallets.push(_wallet);
        
        emit IdentityRegistered(_wallet, _identity);
    }
    
    /**
     * @notice Remove identity for a wallet
     * @param _wallet The wallet address
     */
    function removeIdentity(address _wallet) external override onlyTrustedIssuer {
        address identity = _identities[_wallet];
        require(identity != address(0), "Identity not found");
        
        _verifiedIdentities[identity] = false;
        delete _identities[_wallet];
        
        // Remove from array (swap and pop)
        for (uint256 i = 0; i < _registeredWallets.length; i++) {
            if (_registeredWallets[i] == _wallet) {
                _registeredWallets[i] = _registeredWallets[_registeredWallets.length - 1];
                _registeredWallets.pop();
                break;
            }
        }
        
        emit IdentityRemoved(_wallet, identity);
    }
    
    /**
     * @notice Update identity for a wallet
     * @param _wallet The wallet address
     * @param _identity The new identity contract address
     */
    function updateIdentity(
        address _wallet,
        address _identity
    ) external override onlyTrustedIssuer {
        require(_identity != address(0), "Invalid identity");
        address oldIdentity = _identities[_wallet];
        require(oldIdentity != address(0), "Identity not found");
        
        _verifiedIdentities[oldIdentity] = false;
        _identities[_wallet] = _identity;
        _verifiedIdentities[_identity] = true;
        
        emit IdentityUpdated(_wallet, _identity);
    }
    
    /**
     * @notice Batch register identities
     * @param _wallets Array of wallet addresses
     * @param _identities Array of identity contract addresses
     */
    function batchRegisterIdentities(
        address[] calldata _wallets,
        address[] calldata _identities
    ) external override onlyTrustedIssuer {
        require(_wallets.length == _identities.length, "Arrays length mismatch");
        
        for (uint256 i = 0; i < _wallets.length; i++) {
            require(_wallets[i] != address(0), "Invalid wallet");
            require(_identities[i] != address(0), "Invalid identity");
            require(_identities[_wallets[i]] == address(0), "Identity already exists");
            
            _identities[_wallets[i]] = _identities[i];
            _verifiedIdentities[_identities[i]] = true;
            _registeredWallets.push(_wallets[i]);
            
            emit IdentityRegistered(_wallets[i], _identities[i]);
        }
    }
    
    /**
     * @notice Get identity count
     * @return count Number of registered identities
     */
    function getIdentityCount() external view override returns (uint256 count) {
        return _registeredWallets.length;
    }
    
    /**
     * @notice Check if identity is registered
     * @param _identity The identity contract address
     * @return isRegistered True if registered
     */
    function isRegistered(address _identity) external view override returns (bool) {
        return _verifiedIdentities[_identity];
    }
    
    /**
     * @notice Get all registered wallets
     * @return wallets Array of wallet addresses
     */
    function getRegisteredWallets() external view returns (address[] memory) {
        return _registeredWallets;
    }
    
    /**
     * @notice Verify an identity (can be called by trusted issuer)
     * @param _identity The identity contract address to verify
     */
    function verifyIdentity(address _identity) external onlyTrustedIssuer {
        require(_identity != address(0), "Invalid identity");
        _verifiedIdentities[_identity] = true;
    }
    
    /**
     * @notice Revoke verification for an identity
     * @param _identity The identity contract address to revoke
     */
    function revokeIdentity(address _identity) external onlyTrustedIssuer {
        _verifiedIdentities[_identity] = false;
    }
}
