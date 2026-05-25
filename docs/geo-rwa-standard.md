# Geography-Aware RWA Token Standard — Draft Specification

**Status:** Draft v0.1
**Extends:** ERC-3643 (T-REX), ERC-20
**Reference Implementation:** `contracts/JurisdictionCompliance.sol`

## Abstract

This specification defines a geography-aware extension to the ERC-3643 RWA token standard. It enables token issuers to enforce transfer restrictions based on the jurisdictions of both sender and receiver, investor accreditation categories, and cross-jurisdiction compliance rules. The standard is designed for regulatory regimes where securities laws differ by geography (e.g., US Regulation D vs EU MiFID vs Singapore SFA).

## 1. Motivation

Real-world asset tokenization requires compliance with securities regulations across multiple jurisdictions. Current token standards either:

- Permit unrestricted transfers (ERC-20), unsuitable for regulated assets
- Apply simple whitelist gating (BasicCompliance), which ignores jurisdiction compatibility

A geography-aware standard is needed because:

1. **Regulatory compatibility**: US-accredited investors can trade with EU-qualified investors, but US-retail cannot trade with EU-retail in the same security
2. **Issuer control**: The issuer must know the jurisdiction of every token holder for reporting, withholding, and disclosure
3. **Cross-jurisdiction mapping**: Certain jurisdiction pairs are pre-approved (US↔EU, SG↔UK); others require special exemptions

## 2. Core Concepts

### 2.1 Jurisdiction Codes

Jurisdictions are identified by ISO 3166-1 alpha-2 codes stored as `bytes32` (keccak256 hash of the code).

### 2.2 Investor Categories

| Category | Description | Typical Restrictions |
|----------|-------------|---------------------|
| `accredited` | Accredited/qualified investor | Can trade across most partner jurisdictions |
| `retail` | Non-accredited retail investor | Restricted to same-jurisdiction transfers |
| `qualified` | Institutional investor | Broadest transfer permissions |
| `blocked` | Prohibited from holding tokens | No transfers allowed |

### 2.3 Compliance Rules

- **Same-jurisdiction**: transfers allowed by default (configurable)
- **Cross-jurisdiction**: each directed pair (from → to) must be explicitly allowed
- **Category gating**: certain category → category transfers may be restricted even within the same jurisdiction

## 3. Interface

```solidity
interface IGeoCompliance {
    // --- Registration ---
    function registerInvestor(address investor, bytes32 jurisdiction, bytes32 category) external;
    function updateInvestor(address investor, bytes32 jurisdiction, bytes32 category) external;
    function removeInvestor(address investor) external;

    // --- Compliance Checks ---
    function isTransferCompliant(address from, address to) external view returns (bool);
    function isTransferFromCompliant(address from) external view returns (bool);
    function isTransferToCompliant(address to) external view returns (bool);

    // --- Configuration ---
    function setAllowedTransfer(bytes32 fromJurisdiction, bytes32 toJurisdiction, bool allowed) external;
    function setAllowedCategoryTransfer(bytes32 fromCategory, bytes32 toCategory, bool allowed) external;
    function setSameJurisdictionDefault(bool allowed) external;

    // --- Queries ---
    function getInvestor(address investor) external view returns (bytes32 jurisdiction, bytes32 category, bool registered);
    function getInvestorCount() external view returns (uint256);
    function isJurisdictionTransferAllowed(bytes32 from, bytes32 to) external view returns (bool);
    function isCategoryTransferAllowed(bytes32 from, bytes32 to) external view returns (bool);

    // --- Events ---
    event InvestorRegistered(address indexed investor, bytes32 jurisdiction, bytes32 category);
    event InvestorUpdated(address indexed investor, bytes32 oldJurisdiction, bytes32 newJurisdiction, bytes32 oldCategory, bytes32 newCategory);
    event InvestorRemoved(address indexed investor);
    event TransferAllowed(bytes32 indexed fromJurisdiction, bytes32 indexed toJurisdiction);
    event TransferBlocked(bytes32 indexed fromJurisdiction, bytes32 indexed toJurisdiction);
}
```

## 4. Default Jurisdiction Matrix

| From \ To | US | EU | UK | SG | JP | CH | AU | HK |
|-----------|----|----|----|----|----|----|----|----|
| US | Y | Y | Y | Y |   |   |   |   |
| EU | Y | Y | Y | Y |   |   |   |   |
| UK | Y | Y | Y | Y |   |   |   |   |
| SG | Y | Y | Y | Y |   |   |   |   |
| JP |   |   |   |   | Y |   |   |   |
| CH |   |   |   |   |   | Y |   |   |
| AU |   |   |   |   |   |   | Y |   |
| HK |   |   |   |   |   |   |   | Y |

(Y = allowed by default, blank = blocked unless explicitly configured)

The matrix should be extended by governance as regulatory agreements are formalized.

## 5. Integration with ERC-3643

The geography-aware compliance module acts as a drop-in replacement for `BasicCompliance`:

```
ERC3643Token
    │
    ├── IdentityRegistry  (unchanged)
    │
    └── JurisdictionCompliance (replaces BasicCompliance)
            │
            └── isTransferCompliant(from, to)
                    │
                    ├── is same jurisdiction? → sameJurisdictionAllowedByDefault
                    ├── explicit pair allowed? → allowedTransfers[from][to]
                    └── category check → allowedCategoryTransfers[fromCat][toCat]
```

## 6. Security Considerations

1. **Jurisdiction spoofing**: the issuer (owner) assigns jurisdictions. A compromised owner key could assign false jurisdictions. Mitigation: multi-sig governance, timelock on jurisdiction changes.
2. **Front-running category changes**: an investor could request a category upgrade before a trade. Mitigation: enforce a cooldown period (e.g., 24h) after category changes.
3. **Gas costs**: the dual check (jurisdiction + category) approximately doubles compliance gas costs versus a simple whitelist. Mitigation: batch-checks for market makers.

## 7. Open Questions (v0.1 → v0.2)

- Should jurisdiction be bound to the address immutably (soulbound) or allow updates?
- How should partial-jurisdiction investors be handled (e.g., US person living in Singapore)?
- Should the standard define jurisdictional attestations (Verifiable Credentials) rather than on-chain mapping?
- What is the dispute resolution mechanism for incorrect jurisdiction assignments?

## 8. References

- ERC-3643 (T-REX): https://eips.ethereum.org/EIPS/eip-3643
- JurisdictionCompliance.sol: kcolbchain/rwa-toolkit contracts/
- SEC Regulation D: https://www.sec.gov/rules-regulations
- EU MiFID II: https://www.esma.europa.eu/policy-rules/investor-protection/mifid-ii
- Singapore SFA: https://www.mas.gov.sg/regulation/securities-and-futures-act
