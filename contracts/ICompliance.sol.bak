// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title ICompliance
 * @dev Interface for compliance checks on token transfers
 */
interface ICompliance {
    /**
     * @notice Emitted when a transfer is checked
     */
    event TransferChecked(address indexed from, address indexed to, uint256 amount, bool valid);
    
    /**
     * @notice Checks if a transfer is compliant with regulations
     * @param _from Sender address
     * @param _to Receiver address
     * @param _amount Transfer amount
     * @return valid True if the transfer is compliant
     */
    function canTransfer(
        address _from,
        address _to,
        uint256 _amount
    ) external view returns (bool valid);
    
    /**
     * @notice Checks if a transfer from is compliant
     * @param _from Sender address
     * @param _amount Transfer amount
     * @return valid True if the transfer is compliant
     */
    function canTransferFrom(
        address _from,
        uint256 _amount
    ) external view returns (bool valid);
    
    /**
     * @notice Checks if a transfer to is compliant
     * @param _to Receiver address
     * @param _amount Transfer amount
     * @return valid True if the transfer is compliant
     */
    function canTransferTo(
        address _to,
        uint256 _amount
    ) external view returns (bool valid);
    
    /**
     * @notice Creates a compliance rule
     * @param _ruleId Rule identifier
     * @param _ruleData Rule data
     */
    function createRule(bytes32 _ruleId, bytes calldata _ruleData) external;
    
    /**
     * @notice Removes a compliance rule
     * @param _ruleId Rule identifier
     */
    function removeRule(bytes32 _ruleId) external;
    
    /**
     * @notice Checks if a rule exists
     * @param _ruleId Rule identifier
     */
    function hasRule(bytes32 _ruleId) external view returns (bool);
    
    /**
     * @notice Returns the binding status of a token
     * @param _token Token address
     */
    function isTokenBound(address _token) external view returns (bool);
    
    /**
     * @notice Binds a token to this compliance contract
     * @param _token Token address
     */
    function bindToken(address _token) external;
    
    /**
     * @notice Unbinds a token from this compliance contract
     * @param _token Token address
     */
    function unbindToken(address _token) external;
}
