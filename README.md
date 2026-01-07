# Jobs Protocol

Smart contract protocol consisting of an ERC20 token, staking, and vesting modules.
Designed with production readiness, testing rigor, and security in mind.

---

## Overview

The protocol includes:
- **ERC20 token** with access control, supply constraints, and safety features
- **Staking contract** with reward accounting and security protections
- **Vesting contract** for time-based token distribution

The system is built and tested using Foundry, with emphasis on correctness,
security, and real-world robustness.

---

## Contracts

- `JobsTokenFullV2.sol`
  - ERC20 token implementation
  - AccessControl-based roles
  - Optional cap, pause, burn, and permit support

- `JobsTokenStaking.sol`
  - Stake / unstake / claim reward flow
  - Reward accounting with pool updates
  - Reentrancy protection and safe token handling

- `JobsTokenVestingERC20.sol`
  - Linear vesting schedules
  - Claimable token tracking per beneficiary

---

## Architecture Notes

- Staking and reward logic is separated from token logic
- Reward accounting is updated on each user interaction
- Access-controlled admin functions are isolated
- No upgradeability is assumed unless explicitly added

---

## Build & Test

### Install dependencies
```bash
forge install
