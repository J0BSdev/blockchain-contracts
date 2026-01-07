
# Security Overview

This protocol manages user funds and time-based token distribution.
Security considerations are taken seriously, but no system is risk-free.

---

## Threat Model

### Assets
- Staked token balances
- Reward token balances
- Vesting allocations
- Administrative privileges

### Trust Assumptions
- Admin roles are controlled securely
- Reward funding is correctly configured
- Tokens used are standard ERC20 unless explicitly stated otherwise

---

## Access Control

Privileged operations are protected via AccessControl.
Typical admin actions may include:
- configuring reward parameters
- pausing protocol components
- managing roles

For production use, multisig ownership and timelocks are recommended.

---

## Testing Strategy

- **Unit tests** validate expected behavior
- **Fuzz tests** explore randomized execution paths
- **Invariant tests** enforce protocol-level guarantees
- **Fork-based tests** simulate real-chain attack scenarios

Key invariants include:
- rewards cannot exceed accounted amounts
- staking balances remain consistent
- unauthorized access is not possible

---

## Static Analysis

- **Slither** is used for pattern-based static analysis
- **Mythril** is used for symbolic execution and path exploration

Static analysis complements, but does not replace, manual review
and economic reasoning.

---

## Limitations

- Non-standard ERC20 tokens may not be supported
- Economic assumptions depend on correct configuration
- Admin key compromise is out of scope without multisig

---

## Vulnerability Disclosure

If a vulnerability is discovered:
- Do not disclose publicly
- Provide a clear description and reproduction steps
- Contact: TBD
