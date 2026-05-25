// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./IComplianceEngine.sol";

contract KaioToken is ERC20, Ownable, Pausable {
    IComplianceEngine public complianceEngine;

    uint8 private _tokenDecimals;

    event ComplianceEngineSet(address indexed engine);
    event ComplianceCheckFailed(address indexed from, address indexed to, uint256 amount, string reason);

    error TransferNotCompliant(string reason);
    error InvalidAddress();

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 initialSupply,
        address complianceEngine_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        _tokenDecimals = decimals_;
        complianceEngine = IComplianceEngine(complianceEngine_);
        _mint(msg.sender, initialSupply);
    }

    function decimals() public view virtual override returns (uint8) {
        return _tokenDecimals;
    }

    function setComplianceEngine(address _engine) external onlyOwner {
        if (_engine == address(0)) revert InvalidAddress();
        complianceEngine = IComplianceEngine(_engine);
        emit ComplianceEngineSet(_engine);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        (bool allowed, string memory reason) = complianceEngine.checkTransfer(msg.sender, to, amount, "");
        if (!allowed) {
            emit ComplianceCheckFailed(msg.sender, to, amount, reason);
            revert TransferNotCompliant(reason);
        }
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        (bool allowed, string memory reason) = complianceEngine.checkTransfer(from, to, amount, "");
        if (!allowed) {
            emit ComplianceCheckFailed(from, to, amount, reason);
            revert TransferNotCompliant(reason);
        }
        return super.transferFrom(from, to, amount);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        (bool allowed, string memory reason) = complianceEngine.checkTransfer(address(0), to, amount, "");
        if (!allowed) revert TransferNotCompliant(reason);
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }

    function pause() external onlyOwner { _pause(); }
    function unpause() external onlyOwner { _unpause(); }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }
}
