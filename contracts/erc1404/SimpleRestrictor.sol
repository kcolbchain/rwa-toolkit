// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";

contract SimpleRestrictor is Ownable {
    enum RestrictionCode {
        OK,
        SenderNotWhitelisted,
        ReceiverNotWhitelisted,
        SenderFrozen,
        ReceiverFrozen,
        AmountExceedsLimit,
        JurisdictionMismatch
    }

    mapping(address => bool) public whitelisted;
    mapping(address => bool) public frozen;
    mapping(address => uint256) public maxTransferAmount;
    uint256 public globalMaxTransferAmount;

    event Whitelisted(address indexed account, bool status);
    event Frozen(address indexed account, bool status);
    event MaxTransferSet(address indexed account, uint256 amount);
    event GlobalMaxTransferSet(uint256 amount);

    constructor(address _admin) Ownable(_admin) {
        globalMaxTransferAmount = type(uint256).max;
    }

    function setWhitelisted(address account, bool status) external onlyOwner {
        whitelisted[account] = status;
        emit Whitelisted(account, status);
    }

    function setFrozen(address account, bool _frozen) external onlyOwner {
        frozen[account] = _frozen;
        emit Frozen(account, _frozen);
    }

    function setMaxTransferAmount(address account, uint256 amount) external onlyOwner {
        maxTransferAmount[account] = amount;
        emit MaxTransferSet(account, amount);
    }

    function setGlobalMaxTransferAmount(uint256 amount) external onlyOwner {
        globalMaxTransferAmount = amount;
        emit GlobalMaxTransferSet(amount);
    }

    function detectTransferRestriction(
        address from,
        address to,
        uint256 amount
    ) external view returns (uint8) {
        if (from != address(0) && !whitelisted[from]) return uint8(RestrictionCode.SenderNotWhitelisted);
        if (to != address(0) && !whitelisted[to]) return uint8(RestrictionCode.ReceiverNotWhitelisted);
        if (frozen[from]) return uint8(RestrictionCode.SenderFrozen);
        if (frozen[to]) return uint8(RestrictionCode.ReceiverFrozen);
        uint256 maxAmt = maxTransferAmount[from];
        if (maxAmt == 0) maxAmt = globalMaxTransferAmount;
        if (amount > maxAmt) return uint8(RestrictionCode.AmountExceedsLimit);
        return uint8(RestrictionCode.OK);
    }

    function messageForTransferRestriction(uint8 restrictionCode) external pure returns (string memory) {
        if (restrictionCode == uint8(RestrictionCode.OK)) return "No restrictions";
        if (restrictionCode == uint8(RestrictionCode.SenderNotWhitelisted)) return "Sender not whitelisted";
        if (restrictionCode == uint8(RestrictionCode.ReceiverNotWhitelisted)) return "Receiver not whitelisted";
        if (restrictionCode == uint8(RestrictionCode.SenderFrozen)) return "Sender frozen";
        if (restrictionCode == uint8(RestrictionCode.ReceiverFrozen)) return "Receiver frozen";
        if (restrictionCode == uint8(RestrictionCode.AmountExceedsLimit)) return "Amount exceeds transfer limit";
        if (restrictionCode == uint8(RestrictionCode.JurisdictionMismatch)) return "Jurisdiction mismatch";
        return "Unknown restriction";
    }
}
