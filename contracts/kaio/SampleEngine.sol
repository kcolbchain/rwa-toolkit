// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./IComplianceEngine.sol";

contract SampleEngine is IComplianceEngine, Ownable {
    mapping(address => bool) public compliantAccounts;
    mapping(bytes32 => bytes) public policies;

    event AccountComplianceSet(address indexed account, bool compliant);
    event PolicySet(bytes32 indexed key, bytes value);

    constructor(address _admin) Ownable(_admin) {}

    function setAccountCompliance(address account, bool _compliant) external onlyOwner {
        compliantAccounts[account] = _compliant;
        emit AccountComplianceSet(account, _compliant);
    }

    function checkTransfer(
        address from,
        address to,
        uint256 amount,
        bytes calldata
    ) external view override returns (bool allowed, string memory reason) {
        if (!compliantAccounts[from]) return (false, "Sender not compliant");
        if (!compliantAccounts[to]) return (false, "Receiver not compliant");
        uint256 maxAmount = abi.decode(policies[keccak256("maxTransferAmount")], (uint256));
        if (maxAmount > 0 && amount > maxAmount) return (false, "Amount exceeds limit");
        return (true, "");
    }

    function isAddressCompliant(address account) external view override returns (bool) {
        return compliantAccounts[account];
    }

    function setPolicy(bytes32 key, bytes calldata value) external override onlyOwner {
        policies[key] = value;
        emit PolicySet(key, value);
    }

    function getPolicy(bytes32 key) external view override returns (bytes memory) {
        return policies[key];
    }
}
