# 🎯 JobsTokenStaking - Allowance, Balance & Flow

> **Complete guide to token flow, allowances, and balances in the staking contract**

---

## 📑 Table of Contents

- [📊 Balance Tracking](#-balance-tracking)
- [🔐 Allowance Flow](#-allowance-flow)
- [💰 Token Flow Diagrams](#-token-flow-diagrams)
- [🔄 Complete Flow Analysis](#-complete-flow-analysis)
- [📝 Key Points Summary](#-key-points-summary)
- [🧪 Test Commands](#-test-commands)

---

## 📊 Contract State Variables

### State Variables (Lines 20-29)

```solidity
IERC20 public immutable stakingToken;          // Line 20 - token koji user stakea
IMintableERC20 public immutable rewardToken;   // Line 21 - token koji se mint-a kao reward

uint256 public rewardRatePerSecond;            // Line 23 - emission rate
uint256 public lastUpdateTime;                 // Line 24 - zadnje ažuriranje
uint256 public accRewardPerShare;              // Line 25 - accumulated reward per share (scaled by 1e18)
uint256 public totalStaked;                    // Line 26 - ukupno stakano

mapping(address => uint256) public balanceOf;  // Line 28 - koliko user stakea
mapping(address => uint256) public rewardDebt; // Line 29 - bookkeeping za rewards
```

---

## 📊 Balance Tracking

### 👤 User Balance
```solidity
mapping(address => uint256) public balanceOf;  // Line 28
```

- **Purpose**: Koliko tokena user ima stakano
- **Changes**: 
  - ➕ Povećava se na `stake()` (line 102)
  - ➖ Smanjuje se na `unstake()` (line 122)

**Query:**
```bash
cast call $STAKING_ADDRESS "balanceOf(address)(uint256)" $WALLET --rpc-url $RPC_URL
```

---

### 📈 Total Staked
```solidity
uint256 public totalStaked;  // Line 26
```

- **Purpose**: Ukupno tokena stakano od svih usera
- **Changes**:
  - ➕ Povećava se na `stake()` (line 103)
  - ➖ Smanjuje se na `unstake()` (line 123)

**Query:**
```bash
cast call $STAKING_ADDRESS "totalStaked()(uint256)" --rpc-url $RPC_URL
```

---

### 💼 Contract Balance (implicitno)
```solidity
stakingToken.balanceOf(address(this))  // ERC20 standard
```

- **Purpose**: Koliko tokena staking kontrakt ima u sebi
- **Note**: Trebao bi biti jednak `totalStaked` (osim ako netko slučajno pošalje tokene direktno)

**Query:**
```bash
cast call $STAKING_TOKEN "balanceOf(address)(uint256)" $STAKING_ADDRESS --rpc-url $RPC_URL
```

---

## 🔐 Allowance Flow

### ⚠️ **Kritično**: User mora dati allowance PRIJE stake-a!

#### Step 1: Approve Tokens
```solidity
// Line 100: stake() koristi safeTransferFrom
stakingToken.safeTransferFrom(msg.sender, address(this), amount);
```

**User mora prvo approve-ati:**
```solidity
stakingToken.approve(stakingContractAddress, amount);
```

**Cast komanda za approve:**
```bash
cast send $STAKING_TOKEN "approve(address,uint256)" $STAKING_ADDRESS $AMOUNT \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

**Provjeri allowance:**
```bash
cast call $STAKING_TOKEN "allowance(address,address)(uint256)" $WALLET $STAKING_ADDRESS --rpc-url $RPC_URL
```

---

#### Step 2: Stake koristi `safeTransferFrom` (Line 100)

```solidity
// Line 15: using SafeERC20 for IERC20;
using SafeERC20 for IERC20;

// Line 100: Transfer tokens from user to contract
stakingToken.safeTransferFrom(msg.sender, address(this), amount);
```

**Key Points:**
- ✅ Koristi `SafeERC20` (line 15) za siguran transfer
- ✅ Automatski provjerava allowance
- ❌ Ako nema dovoljno allowance → **revert**

---

## 💰 Token Flow Diagrams

### 🔵 STAKE Flow
```
┌─────────────┐
│ User Wallet │
└──────┬──────┘
       │
       │ 1️⃣ approve(stakingContract, amount)
       ├─────────────────────────────────────→ ┌──────────────────────┐
       │                                        │ StakingToken Contract│
       │                                        └──────────────────────┘
       │
       │ 2️⃣ stake(amount)
       ├─────────────────────────────────────→ ┌──────────────────────┐
       │                                        │  Staking Contract     │
       │                                        │                       │
       │                                        │  ┌──────────────────┐ │
       │                                        │  │ safeTransferFrom │ │
       │                                        │  │ (Line 100)       │ │
       │                                        │  └────────┬─────────┘ │
       │                                        │           │            │
       │                                        │           ▼            │
       │                                        │  ┌──────────────────┐ │
       │                                        │  │ Transfer tokens │ │
       │                                        │  │ user → contract │ │
       │                                        │  └──────────────────┘ │
       │                                        │                       │
       │                                        │  balanceOf[user] +=   │
       │                                        │  totalStaked +=       │
       │                                        └──────────────────────┘
```

---

### 🟢 UNSTAKE Flow
```
┌──────────────────────┐
│  Staking Contract    │
│                      │
│  1️⃣ unstake(amount)  │
│     ├─→ balanceOf[user] -= amount
│     └─→ totalStaked -= amount
│                      │
│  2️⃣ safeTransfer()   │
│     (Line 127)       │
└──────────┬───────────┘
           │
           ▼
┌──────────────────────┐
│ StakingToken Contract │
│                      │
│  Transfer:           │
│  contract → user     │
└──────────────────────┘
```

---

### 🟡 REWARD Flow
```
┌──────────────────────┐
│ RewardToken Contract │
│                      │
│  1️⃣ claim()          │
│     ili              │
│     stake()/unstake()│
│     (auto-harvest)   │
│                      │
│  2️⃣ mint(user, ...)  │
│     (Line 96, 118)   │
│                      │
│  ⚡ Mint: 0 → user   │
│  (direktno, bez      │
│   transfera!)        │
└──────────────────────┘
```

> **💡 Napomena:** Rewards se **mintaju direktno**, ne koriste transfer!

---

## 🔄 Complete Flow Analysis

### 🧮 Core Math Functions

#### `_updatePool()` (Lines 59-73)
**Purpose:** Ažurira accumulated reward per share na temelju vremena koje je prošlo.

```solidity
function _updatePool() internal {
    if (block.timestamp <= lastUpdateTime) return;           // Line 60

    if (totalStaked == 0) {                                  // Line 62
        lastUpdateTime = block.timestamp;                    // Line 63
        return;                                              // Line 64
    }                                                        // Line 65

    uint256 elapsed = block.timestamp - lastUpdateTime;      // Line 67
    uint256 reward = elapsed * rewardRatePerSecond;          // Line 68

    // accRewardPerShare += reward / totalStaked              // Line 70
    accRewardPerShare += (reward * 1e18) / totalStaked;     // Line 71
    lastUpdateTime = block.timestamp;                        // Line 72
}
```

**Key Points:**
- Ažurira `accRewardPerShare` na temelju vremena koje je prošlo
- Koristi `rewardRatePerSecond` za izračun rewards
- Scaled by `1e18` za preciznost

---

#### `pendingRewards()` (Lines 75-85)
**Purpose:** View funkcija koja vraća koliko rewards user može claimati.

```solidity
function pendingRewards(address user) public view returns (uint256) {
    uint256 _acc = accRewardPerShare;                        // Line 76

    if (block.timestamp > lastUpdateTime && totalStaked != 0) {  // Line 78
        uint256 elapsed = block.timestamp - lastUpdateTime;   // Line 79
        uint256 reward = elapsed * rewardRatePerSecond;      // Line 80
        _acc += (reward * 1e18) / totalStaked;               // Line 81
    }                                                        // Line 82

    return (balanceOf[user] * _acc) / 1e18 - rewardDebt[user];  // Line 84
}
```

**Formula:**
```
pending = (balanceOf[user] * accRewardPerShare) / 1e18 - rewardDebt[user]
```

---

## 🔄 User Action Functions

### 📥 Stake Function (Lines 88-108)

**Complete Function Code:**
```solidity
function stake(uint256 amount) external nonReentrant whenNotPaused {
    if (amount == 0) revert ZeroAmount();                    // Line 89

    _updatePool();                                           // Line 91

    // harvest prije promjene balancea                        // Line 93
    uint256 pending = (balanceOf[msg.sender] * accRewardPerShare) / 1e18 - rewardDebt[msg.sender];  // Line 94
    if (pending != 0) {                                      // Line 95
        rewardToken.mint(msg.sender, pending);               // Line 96
        emit Claimed(msg.sender, pending);                   // Line 97
    }                                                        // Line 98

    stakingToken.safeTransferFrom(msg.sender, address(this), amount);  // Line 100 ⚠️ Requires allowance!

    balanceOf[msg.sender] += amount;                         // Line 102
    totalStaked += amount;                                   // Line 103

    rewardDebt[msg.sender] = (balanceOf[msg.sender] * accRewardPerShare) / 1e18;  // Line 105

    emit Staked(msg.sender, amount);                         // Line 107
}
```

**Execution Flow:**

| Step | Line | Action | Code |
|------|------|--------|------|
| 1️⃣ | **89** | ✅ Check amount | `if (amount == 0) revert ZeroAmount()` |
| 2️⃣ | **91** | 🔄 Update pool | `_updatePool()` - ažurira `accRewardPerShare` |
| 3️⃣ | **94-98** | 💰 Harvest rewards | `pending = (balanceOf[user] * accRewardPerShare) / 1e18 - rewardDebt[user]`<br>`if (pending > 0) rewardToken.mint(user, pending)` |
| 4️⃣ | **100** | 🔐 Transfer tokens | `stakingToken.safeTransferFrom(user, contract, amount)`<br>⚠️ **Zahtijeva allowance!** |
| 5️⃣ | **102-103** | 📊 Update balances | `balanceOf[user] += amount`<br>`totalStaked += amount` |
| 6️⃣ | **105** | 📝 Update debt | `rewardDebt[user] = (balanceOf[user] * accRewardPerShare) / 1e18` |

---

### 📤 Unstake Function (Lines 110-130)

**Complete Function Code:**
```solidity
function unstake(uint256 amount) external nonReentrant whenNotPaused {
    if (amount == 0) revert ZeroAmount();                    // Line 111
    if (balanceOf[msg.sender] < amount) revert InsufficientBalance();  // Line 112

    _updatePool();                                           // Line 114

    uint256 pending = (balanceOf[msg.sender] * accRewardPerShare) / 1e18 - rewardDebt[msg.sender];  // Line 116
    if (pending != 0) {                                      // Line 117
        rewardToken.mint(msg.sender, pending);               // Line 118
        emit Claimed(msg.sender, pending);                   // Line 119
    }                                                        // Line 120

    balanceOf[msg.sender] -= amount;                         // Line 122
    totalStaked -= amount;                                   // Line 123

    rewardDebt[msg.sender] = (balanceOf[msg.sender] * accRewardPerShare) / 1e18;  // Line 125

    stakingToken.safeTransfer(msg.sender, amount);           // Line 127 ✅ No allowance needed!

    emit Unstaked(msg.sender, amount);                       // Line 129
}
```

**Execution Flow:**

| Step | Line | Action | Code |
|------|------|--------|------|
| 1️⃣ | **111-112** | ✅ Check amount & balance | `if (amount == 0) revert ZeroAmount()`<br>`if (balanceOf[user] < amount) revert InsufficientBalance()` |
| 2️⃣ | **114** | 🔄 Update pool | `_updatePool()` |
| 3️⃣ | **116-120** | 💰 Harvest rewards | Isto kao u `stake()` |
| 4️⃣ | **122-123** | 📊 Update balances | `balanceOf[user] -= amount`<br>`totalStaked -= amount` |
| 5️⃣ | **125** | 📝 Update debt | `rewardDebt[user] = (balanceOf[user] * accRewardPerShare) / 1e18` |
| 6️⃣ | **127** | 💸 Transfer back | `stakingToken.safeTransfer(user, amount)`<br>✅ **Ne treba allowance!** |

---

### 💎 Claim Function (Lines 132-142)

**Complete Function Code:**
```solidity
function claim() external nonReentrant whenNotPaused {
    _updatePool();                                           // Line 133

    uint256 pending = (balanceOf[msg.sender] * accRewardPerShare) / 1e18 - rewardDebt[msg.sender];  // Line 135
    if (pending != 0) {                                      // Line 136
        rewardToken.mint(msg.sender, pending);               // Line 137
        emit Claimed(msg.sender, pending);                   // Line 138
    }                                                        // Line 139

    rewardDebt[msg.sender] = (balanceOf[msg.sender] * accRewardPerShare) / 1e18;  // Line 141
}
```

**Execution Flow:**

| Step | Line | Action |
|------|------|--------|
| 1️⃣ | **133** | 🔄 Update pool |
| 2️⃣ | **135** | 📊 Calculate pending |
| 3️⃣ | **136-139** | 💰 Mint rewards |
| 4️⃣ | **141** | 📝 Update reward debt |

---

## 📝 Key Points Summary

### 🔐 Allowance Requirements

| Action | Allowance Required? | Reason |
|--------|---------------------|--------|
| **STAKE** | ✅ **YES** | `safeTransferFrom()` (Line 100) zahtijeva allowance |
| **UNSTAKE** | ❌ **NO** | Kontrakt šalje token nazad useru (Line 127) |
| **CLAIM** | ❌ **NO** | Rewards se mintaju direktno (Line 96, 118, 137) |

---

### 📊 Balance Types

| Variable | Type | Description |
|---------|------|-------------|
| `balanceOf[user]` | `mapping(address => uint256)` | Koliko tokena user ima stakano |
| `totalStaked` | `uint256` | Suma svih `balanceOf` vrijednosti |
| `stakingToken.balanceOf(contract)` | `uint256` | Fizički balance kontrakta (ERC20) |

---

### 🔄 Flow Summary

```
┌─────────────────────────────────────────────────────────┐
│                    STAKE Flow                            │
│  User → Approve → Stake → TransferFrom → Contract       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                   UNSTAKE Flow                          │
│  Contract → Transfer → User                             │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                   REWARD Flow                           │
│  Mint → User (direktno, bez transfera)                 │
└─────────────────────────────────────────────────────────┘
```

---

## 🧪 Test Commands

### 📋 Quick Reference

```bash
# Set variables
export STAKING_ADDRESS="0x..."
export STAKING_TOKEN="0x..."
export WALLET="0x..."
export RPC_URL="https://..."
```

---

### 1️⃣ Check User Balance
```bash
cast call $STAKING_ADDRESS "balanceOf(address)(uint256)" $WALLET --rpc-url $RPC_URL
```
**Returns:** Koliko tokena user ima stakano

---

### 2️⃣ Check Total Staked
```bash
cast call $STAKING_ADDRESS "totalStaked()(uint256)" --rpc-url $RPC_URL
```
**Returns:** Ukupno tokena stakano od svih usera

---

### 3️⃣ Check Allowance (PRIJE stake-a!)
```bash
cast call $STAKING_TOKEN "allowance(address,address)(uint256)" $WALLET $STAKING_ADDRESS --rpc-url $RPC_URL
```
**Returns:** Koliko tokena user može transferirati staking kontraktu

**If 0, approve first:**
```bash
cast send $STAKING_TOKEN "approve(address,uint256)" $STAKING_ADDRESS $AMOUNT \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

---

### 4️⃣ Check Contract Balance
```bash
cast call $STAKING_TOKEN "balanceOf(address)(uint256)" $STAKING_ADDRESS --rpc-url $RPC_URL
```
**Returns:** Fizički balance staking kontrakta (trebao bi biti = totalStaked)

---

### 5️⃣ Check Pending Rewards
```bash
cast call $STAKING_ADDRESS "pendingRewards(address)(uint256)" $WALLET --rpc-url $RPC_URL
```
**Returns:** Koliko rewards user može claimati

---

### 6️⃣ Check Reward Rate
```bash
cast call $STAKING_ADDRESS "rewardRatePerSecond()(uint256)" --rpc-url $RPC_URL
```
**Returns:** Emission rate (tokens per second)

---

### 7️⃣ Check Acc Reward Per Share
```bash
cast call $STAKING_ADDRESS "accRewardPerShare()(uint256)" --rpc-url $RPC_URL
```
**Returns:** Accumulated reward per share (scaled by 1e18)

