# Real Estate Tokenization Example: Fractional Ownership of 123 Main Street

This worked example demonstrates tokenizing a commercial real estate property using the RWA toolkit's ERC-3643 implementation with jurisdiction-aware compliance.

## Property Details

| Attribute | Value |
|-----------|-------|
| Property | 123 Main Street, New York, NY 10001 |
| Type | Commercial office (Class B) |
| Appraised Value | $12,000,000 |
| Token Supply | 1,200,000 tokens ($10 per token) |
| Min Investment | 100 tokens ($1,000) |
| Net Operating Income | $720,000/year (6% cap rate) |
| Token Standard | ERC-3643 with JurisdictionCompliance |

## 1. Setup Steps

### 1.1 Deploy Contracts

```javascript
// 1. Deploy IdentityRegistry
const IdentityRegistry = await ethers.getContractFactory("IdentityRegistry");
const registry = await IdentityRegistry.deploy(owner.address);

// 2. Deploy JurisdictionCompliance
const JurisdictionCompliance = await ethers.getContractFactory("JurisdictionCompliance");
const compliance = await JurisdictionCompliance.deploy(owner.address);

// 3. Deploy ERC3643Token
const ERC3643Token = await ethers.getContractFactory("ERC3643Token");
const token = await ERC3643Token.deploy(
  "123 Main Street Property Token",
  "MAIN123",
  18,
  ethers.parseEther("1200000"), // 1.2M token supply
  registry.target,
  compliance.target
);
```

### 1.2 Configure Jurisdictions

```javascript
// Allow US↔EU transfers (common for cross-border RWA investment)
await compliance.setAllowedTransfer(
  ethers.encodeBytes32String("US"),
  ethers.encodeBytes32String("EU"),
  true
);
await compliance.setAllowedTransfer(
  ethers.encodeBytes32String("EU"),
  ethers.encodeBytes32String("US"),
  true
);

// Allow SG investors to participate
await compliance.setAllowedTransfer(
  ethers.encodeBytes32String("SG"),
  ethers.encodeBytes32String("US"),
  true
);
await compliance.setAllowedTransfer(
  ethers.encodeBytes32String("US"),
  ethers.encodeBytes32String("SG"),
  true
);
```

## 2. Investor Onboarding

### Alice (US Accredited)
```javascript
await registry.registerIdentity(alice.address, identityContract);
await compliance.registerInvestor(
  alice.address,
  ethers.encodeBytes32String("US"),
  ethers.encodeBytes32String("accredited")
);
await token.transfer(alice.address, ethers.parseEther("50000")); // $500,000 investment
```

### Bob (EU Qualified)
```javascript
await registry.registerIdentity(bob.address, identityContract);
await compliance.registerInvestor(
  bob.address,
  ethers.encodeBytes32String("EU"),
  ethers.encodeBytes32String("qualified")
);
await token.transfer(bob.address, ethers.parseEther("30000")); // $300,000 investment
```

### Charlie (SG Retail)
```javascript
await registry.registerIdentity(charlie.address, identityContract);
await compliance.registerInvestor(
  charlie.address,
  ethers.encodeBytes32String("SG"),
  ethers.encodeBytes32String("retail")
);
await token.transfer(charlie.address, ethers.parseEther("1000")); // $10,000 investment
```

## 3. Transfer Scenarios

### Scenario A: US → EU (Allowed)
```
Alice (US accredited) → Bob (EU qualified)
Jurisdiction: US → EU ✓ (explicitly allowed)
Category: accredited → qualified ✓ (explicitly allowed)
Result: TRANSFER ALLOWED
```

### Scenario B: US → SG (Allowed)
```
Alice (US accredited) → Charlie (SG retail)
Jurisdiction: US → SG ✓ (explicitly allowed)
Category: accredited → retail ✗ (not explicitly allowed)
Result: TRANSFER BLOCKED by category rules
```

### Scenario C: SG → US (Allowed for accredited)
```
Charlie (SG) → Alice (US)
Jurisdiction: SG → US ✓ (explicitly allowed)
Category: retail → accredited ✗ (not allowed)
Result: TRANSFER BLOCKED
```

### Scenario D: Same Jurisdiction (Default Allowed)
```
Alice (US) → David (US accredited)
Jurisdiction: US → US ✓ (same-jurisdiction default)
Category: accredited → accredited ✓
Result: TRANSFER ALLOWED
```

## 4. Ownership Structure

After initial sale (assuming all tokens sold at $10/token):

| Investor | Jurisdiction | Category | Tokens | % Ownership | Investment |
|----------|-------------|----------|--------|-------------|------------|
| Alice | US | accredited | 500,000 | 41.67% | $5,000,000 |
| Bob | EU | qualified | 300,000 | 25.00% | $3,000,000 |
| Charlie | SG | retail | 1,000 | 0.08% | $10,000 |
| Others (100 investors) | Mixed | Mixed | 399,000 | 33.25% | $3,990,000 |

## 5. Revenue Distribution

Annual NOI of $720,000 distributed pro-rata:

| Investor | Tokens | Annual Distribution |
|----------|--------|-------------------|
| Alice | 500,000 | $300,000 (41.67%) |
| Bob | 300,000 | $180,000 (25.00%) |
| Charlie | 1,000 | $600 (0.08%) |
| Others | 399,000 | $239,400 (33.25%) |

Distribution mechanism: revenue collected in USDC → distributed via Merkle airdrop or direct transfer.

## 6. Secondary Market Compliance

When an investor sells on the secondary market:

```
Seller (Alice, US accredited) → Buyer (Eve, EU retail)
Jurisdiction check: US → EU ✓
Category check: accredited → retail ✗
Result: BLOCKED — Eve must be qualified/accredited to buy from US-accredited seller
```

```
Seller (Bob, EU qualified) → Buyer (Frank, EU qualified)
Jurisdiction check: EU → EU ✓ (same jurisdiction)
Category check: qualified → qualified ✓
Result: ALLOWED
```

## 7. Governance Rights

Token holders vote on property decisions proportional to their holdings:

```javascript
// Each token = 1 vote
// quorum: 50% of outstanding tokens
// Majority: >50% of votes cast
```

| Decision | Quorum | Alice | Bob | Charlie |
|----------|--------|-------|-----|---------|
| Refinance proposal | 600,000 | 500,000 ✓ | 300,000 ✓ | 1,000 ✓ |
| Property sale | 600,000 | 500,000 ✓ | — | — |
| Lease approval | 600,000 | — | 300,000 ✓ | 1,000 ✗ |

## 8. Risks and Disclosures

1. **Liquidity risk**: secondary market may be thin; tokens may trade below NAV
2. **Regulatory risk**: securities laws may restrict who can hold or trade
3. **Property risk**: vacancy, maintenance costs, market depreciation
4. **Smart contract risk**: bugs in ERC-3643 or compliance contracts
5. **Jurisdiction risk**: investor's jurisdiction may change or become restricted

## 9. Key Takeaways

- Fractional ownership enables investments as low as $1,000
- Jurisdiction-aware compliance ensures regulatory adherence across borders
- Accredited and qualified investors have broader transfer permissions
- Revenue distribution is proportional and automated
- Secondary market compliance is enforced at the contract level
