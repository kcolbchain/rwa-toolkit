// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./SimpleRestrictor.sol";

contract Restricted1404Token is ERC20, Ownable, Pausable {
    SimpleRestrictor public restrictor;

    uint8 private _tokenDecimals;

    event RestrictorSet(address indexed restrictor);
    event TokensFrozen(address indexed wallet, uint256 amount);
    event TokensUnfrozen(address indexed wallet, uint256 amount);

    error TransferRestricted(uint8 restrictionCode);
    error InvalidAddress();

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        uint256 initialSupply,
        address restrictor_
    ) ERC20(name_, symbol_) Ownable(msg.sender) {
        _tokenDecimals = decimals_;
        restrictor = SimpleRestrictor(restrictor_);
        _mint(msg.sender, initialSupply);
    }

    function decimals() public view virtual override returns (uint8) {
        return _tokenDecimals;
    }

    function setRestrictor(address _restrictor) external onlyOwner {
        if (_restrictor == address(0)) revert InvalidAddress();
        restrictor = SimpleRestrictor(_restrictor);
        emit RestrictorSet(_restrictor);
    }

    function detectTransferRestriction(
        address from,
        address to,
        uint256 amount
    ) public view returns (uint8) {
        return restrictor.detectTransferRestriction(from, to, amount);
    }

    function messageForTransferRestriction(uint8 restrictionCode) public view returns (string memory) {
        return restrictor.messageForTransferRestriction(restrictionCode);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        uint8 code = detectTransferRestriction(msg.sender, to, amount);
        if (code != 0) revert TransferRestricted(code);
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        uint8 code = detectTransferRestriction(from, to, amount);
        if (code != 0) revert TransferRestricted(code);
        return super.transferFrom(from, to, amount);
    }

    function mint(address to, uint256 amount) external onlyOwner {
        uint8 code = detectTransferRestriction(address(0), to, amount);
        if (code != 0) revert TransferRestricted(code);
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
