# rwa-toolkit web explorer

Zero-build companion site. Two panels:

1. **Standards side-by-side** — ERC-3643, ERC-1404, KAIO. Where compliance
   lives, identity primitive, DeFi composability, best fit.
2. **Transfer-restriction simulator** — configure a token policy
   (jurisdictions, accreditation, max holders, per-holder cap, lock-up,
   sanctions), pick a `(from, to, amount, block)` attempt, see which checks
   fire and why. Renders the matching reference Solidity hook for the
   selected standard.

## Run locally

```bash
python3 -m http.server -d web 8080
```

## Hosted

- kcolbchain.com/rwa-toolkit/

## Scope

The simulator is a teaching tool — the production check lives on-chain in
`contracts/BasicCompliance.sol` and `contracts/IdentityRegistry.sol`. If a
constraint you care about isn't modelled, open an issue.
