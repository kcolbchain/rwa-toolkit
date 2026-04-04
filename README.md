# rwa-toolkit

> RWA tokenization standard and toolkit — geography-aware, compliance-native

**kcolbchain** — open-source blockchain tools and research since 2015.

## Status

Early development. Looking for contributors! See [open issues](https://github.com/kcolbchain/rwa-toolkit/issues) for ways to help.

## Architecture

This toolkit implements the [ERC-3643 / T-REX](https://eips.ethereum.org/EIPS/eip-3643) standard for compliant security tokens (Real World Assets).

```
contracts/
├── interfaces/
│   ├── IToken.sol              # ERC-3643 token interface
│   ├── IIdentityRegistry.sol   # Identity registry interface
│   └── ICompliance.sol         # Compliance module interface
├── token/
│   └── ERC3643Token.sol        # Main security token (ERC-20 + compliance hooks)
├── registry/
│   └── IdentityRegistry.sol    # Investor identity & KYC/AML registry
└── compliance/
    └── BasicCompliance.sol     # Compliance: investor caps, country restrictions
```

### Core Components

| Contract | Purpose |
|---|---|
| **ERC3643Token** | ERC-20 compatible security token with identity checks on every transfer, pause/freeze/recovery capabilities, and pluggable compliance hooks. |
| **IdentityRegistry** | Registers investor identities with ISO-3166 country codes and accreditation (KYC/AML) status. Designed for extension with on-chain identity or oracle bridges. |
| **BasicCompliance** | Enforces max investor count, max balance per investor, and country-level transfer restrictions. Tracks holder counts via transfer hooks. |

### Transfer Flow

1. Sender calls `transfer(to, amount)` on the token
2. Token checks both sender and receiver are **not frozen** and token is **not paused**
3. Token verifies both parties via `IdentityRegistry.isVerified()` (registered + KYC-cleared)
4. Token calls `Compliance.canTransfer()` — checks country restrictions, investor caps, balance limits
5. Transfer executes; `Compliance.transferred()` hook updates internal tracking

## Quick Start

```bash
git clone https://github.com/kcolbchain/rwa-toolkit.git
cd rwa-toolkit
npm install
```

### Compile

```bash
npx hardhat compile
```

### Test

```bash
npx hardhat test
```

### Deploy (example)

```solidity
// 1. Deploy identity registry
IdentityRegistry registry = new IdentityRegistry();

// 2. Deploy compliance module pointing to registry
BasicCompliance compliance = new BasicCompliance(address(registry));

// 3. Deploy token with registry + compliance
ERC3643Token token = new ERC3643Token(
    "US Real Estate Fund",
    "USREF",
    address(registry),
    address(compliance)
);

// 4. Bind token in compliance module
compliance.bindToken(address(token));

// 5. Configure compliance rules
compliance.setMaxInvestorCount(500);
compliance.setMaxBalancePerInvestor(1_000_000e18);
compliance.addCountryRestriction(408); // e.g. restrict DPRK

// 6. Register investors (KYC/AML integration point)
registry.registerIdentity(investorAddress, 840); // US investor
registry.setAccreditation(investorAddress, true);

// 7. Mint tokens to verified investors
token.mint(investorAddress, 10_000e18);
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to get started. Issues tagged `good-first-issue` are great entry points.

## Links

- **Docs:** https://docs.kcolbchain.com/rwa-toolkit/
- **All projects:** https://docs.kcolbchain.com/
- **kcolbchain:** https://kcolbchain.com

## License

MIT

---

*Founded by [Abhishek Krishna](https://abhishekkrishna.com) • GitHub: [@abhicris](https://github.com/abhicris)*
