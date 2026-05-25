// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IComplianceEngine {
    function checkTransfer(
        address from,
        address to,
        uint256 amount,
        bytes calldata userData
    ) external view returns (bool allowed, string memory reason);

    function isAddressCompliant(address account) external view returns (bool);

    function setPolicy(bytes32 key, bytes calldata value) external;
    function getPolicy(bytes32 key) external view returns (bytes memory);
}
