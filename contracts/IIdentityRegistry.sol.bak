// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title IIdentityRegistry
 * @dev Interface for identity registry that verifies user identities
 */
interface IIdentityRegistry {
    /**
     * @notice Emitted when an identity is registered
     */
    event IdentityRegistered(address indexed wallet, address indexed identity);
    
    /**
     * @notice Emitted when an identity is removed
     */
    event IdentityRemoved(address indexed wallet, address indexed identity);
    
    /**
     * @notice Emitted when an identity is updated
     */
    event IdentityUpdated(address indexed wallet, address indexed identity);
    
    /**
     * @notice Returns the identity contract address for a wallet
     * @param _wallet The wallet address
     * @return identity The identity contract address
     */
    function getIdentity(address _wallet) external view returns (address identity);
    
    /**
     * @notice Checks if a wallet has a verified identity
     * @param _wallet The wallet address to check
     * @return verified True if the wallet has a verified identity
     */
    function isVerified(address _wallet) external view returns (bool verified);
    
    /**
     * @notice Registers an identity for a wallet
     * @param _wallet The wallet address
     * @param _identity The identity contract address
     */
    function registerIdentity(address _wallet, address _identity) external;
    
    /**
     * @notice Removes an identity for a wallet
     * @param _wallet The wallet address
     */
    function removeIdentity(address _wallet) external;
    
    /**
     * @notice Updates an identity for a wallet
     * @param _wallet The wallet address
     * @param _identity The new identity contract address
     */
    function updateIdentity(address _wallet, address _identity) external;
    
    /**
     * @notice Batch register identities
     * @param _wallets Array of wallet addresses
     * @param _identities Array of identity contract addresses
     */
    function batchRegisterIdentities(
        address[] calldata _wallets,
        address[] calldata _identities
    ) external;
    
    /**
     * @notice Returns the number of registered identities
     */
    function getIdentityCount() external view returns (uint256);
    
    /**
     * @notice Checks if an identity is registered
     * @param _identity The identity contract address
     */
    function isRegistered(address _identity) external view returns (bool);
}
