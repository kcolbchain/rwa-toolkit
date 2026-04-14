// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IERC3643
 * @dev Interface for the ERC-3643 (T-REX) security token standard
 */
interface IERC3643 is IERC20 {
    /**
     * @notice Emitted when the identity registry is set
     */
    event IdentityRegistrySet(address indexed identityRegistry);
    
    /**
     * @notice Emitted when the compliance contract is set
     */
    event ComplianceSet(address indexed compliance);
    
    /**
     * @notice Emitted when an address is frozen
     */
    event AddressFrozen(address indexed wallet, bool frozen);
    
    /**
     * @notice Returns the identity registry contract address
     */
    function identityRegistry() external view returns (address);
    
    /**
     * @notice Returns the compliance contract address
     */
    function compliance() external view returns (address);
    
    /**
     * @notice Sets the identity registry contract
     */
    function setIdentityRegistry(address _identityRegistry) external;
    
    /**
     * @notice Sets the compliance contract
     */
    function setCompliance(address _compliance) external;
    
    /**
     * @notice Freezes/unfreezes an address
     */
    function setAddressFrozen(address _wallet, bool _frozen) external;
    
    /**
     * @notice Batch freeze addresses
     */
    function batchSetAddressFrozen(address[] calldata _wallets, bool _frozen) external;
    
    /**
     * @notice Checks if a transfer is valid
     */
    function isTransferValid(address _from, address _to, uint256 _amount) external view returns (bool);
    
    /**
     * @notice Mints new tokens
     */
    function mint(address _to, uint256 _amount) external;
    
    /**
     * @notice Burns tokens
     */
    function burn(address _from, uint256 _amount) external;
    
    /**
     * @notice Batch transfer tokens
     */
    function batchTransfer(address[] calldata _recipients, uint256[] calldata _amounts) external returns (bool);
    
    /**
     * @notice Returns token information
     */
    function getTokenInfo() external view returns (
        string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 totalSupply,
        address identityRegistry,
        address compliance,
        string memory version
    );
}
