# ERC-3643 (T-REX) RWA Token Toolkit

A complete implementation of the ERC-3643 (T-REX) security token standard for Real World Assets (RWA) on Ethereum.

## Overview

This toolkit provides a production-ready implementation of the ERC-3643 standard, which enables:

- **Identity-verified token holders** through on-chain identity registry
- **Compliance checks** for all token transfers
- **Investor eligibility verification** before token transfers
- **Regulatory compliance** through programmable rules
- **Flexible permissioning** for different types of assets

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    ERC3643Token                              │
│              (Security Token - ERC20)                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────────┐    ┌─────────────────────┐        │
│  │ IdentityRegistry    │    │ BasicCompliance     │        │
│  │                     │    │                     │        │
│  │ - User verification │    │ - Whitelist         │        │
│  │ - Trusted issuers   │    │ - Transfer limits   │        │
│  │ - Identity binding  │    │ - Custom rules      │        │
│  └─────────────────────┘    └─────────────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## Features

### ERC3643Token
- Full ERC-20 compatibility with security extensions
- Identity verification for all transfers
- Transfer compliance checks
- Batch operations
- Pausable functionality
- Owner-controlled minting/burning
- Address freezing capability

### IdentityRegistry
- On-chain identity verification
- Trusted issuer management
- Batch identity registration
- Identity updates and revocation
- Verification status tracking

### BasicCompliance
- Whitelist-based access control
- Transfer amount limits (per address and global)
- Custom compliance rules framework
- Token binding for multi-token compliance
- Batch whitelist management

## Installation

```bash
npm install
npm run compile
```

## Usage

### 1. Deploy IdentityRegistry

```javascript
const IdentityRegistry = await ethers.getContractFactory("IdentityRegistry");
const registry = await IdentityRegistry.deploy(owner.address);
await registry.deployed();
```

### 2. Deploy BasicCompliance

```javascript
const BasicCompliance = await ethers.getContractFactory("BasicCompliance");
const compliance = await BasicCompliance.deploy(owner.address);
await compliance.deployed();
```

### 3. Deploy ERC3643Token

```javascript
const ERC3643Token = await ethers.getContractFactory("ERC3643Token");
const token = await ERC3643Token.deploy(
  "Real World Asset Token",
  "RWA",
  18, // decimals
  ethers.utils.parseEther("1000000"), // initial supply
  registry.address,
  compliance.address
);
await token.deployed();
```

### 4. Configure Identity and Compliance

```javascript
// Add trusted issuer
await registry.addTrustedIssuer(issuer.address);

// Register identity for user
await registry.registerIdentity(user.address, identityContract.address);

// Whitelist addresses
await compliance.addToWhitelist(user.address);
await compliance.addToWhitelist(recipient.address);

// Bind token to compliance
await compliance.bindToken(token.address);
```

### 5. Transfer Tokens

```javascript
// Transfer (requires identity verification and compliance)
await token.transfer(recipient.address, amount);
```

## Key Functions

### ERC3643Token
- `setIdentityRegistry(address)` - Set identity registry
- `setCompliance(address)` - Set compliance contract
- `setAddressFrozen(address, bool)` - Freeze/unfreeze address
- `mint(address, uint256)` - Mint tokens (owner only)
- `burn(address, uint256)` - Burn tokens (owner only)
- `isTransferValid(from, to, amount)` - Check if transfer is valid

### IdentityRegistry
- `registerIdentity(wallet, identity)` - Register identity
- `isVerified(wallet)` - Check if wallet is verified
- `addTrustedIssuer(issuer)` - Add trusted issuer
- `batchRegisterIdentities(wallets, identities)` - Batch registration

### BasicCompliance
- `addToWhitelist(address)` - Add to whitelist
- `canTransfer(from, to, amount)` - Check transfer compliance
- `setMaxTransferAmount(address, amount)` - Set transfer limit
- `createRule(ruleId, ruleData)` - Create custom rule

## Interfaces

The implementation includes standard interfaces:
- `IERC3643` - Main token interface
- `IIdentityRegistry` - Identity registry interface
- `ICompliance` - Compliance interface

## Security

- All transfers require identity verification
- Compliance checks on every transfer
- Owner-controlled administrative functions
- Pausable in emergency situations
- Address freezing capability for suspicious accounts

## License

MIT

## Bounty

This implementation addresses kcolbchain/rwa-toolkit#3

**Features Implemented:**
- ✅ ERC-3643 core interfaces
- ✅ Identity Registry with trusted issuers
- ✅ Basic Compliance with whitelist and transfer limits
- ✅ Full token implementation with all security features
- ✅ Batch operations for efficiency
- ✅ Comprehensive documentation
