# 📚 JobsToken Ecosystem - Kompletna Dokumentacija

> **Kompletan vodič za sve kontrakte: Token, Staking, i Vesting**

---

## 📑 Table of Contents

- [🏗️ Arhitektura](#️-arhitektura)
- [1. JobsTokenFullV2 (ERC20 Token)](#1-jobstokenfullv2-erc20-token)
- [2. JobsTokenStaking](#2-jobstokenstaking)
- [3. JobsTokenVestingERC20](#3-jobstokenvestingerc20)
- [4. Staking vs Vesting](#4-staking-vs-vesting)
- [5. Cast Komande](#5-cast-komande)
- [6. Deploy Flow](#6-deploy-flow)
- [7. Status Provjere](#7-status-provjere)

---

## 🏗️ Arhitektura

```
┌─────────────────────────────────────────────────────────┐
│              JobsTokenFullV2 (ERC20)                    │
│        0x606fae14A25Ffb18A7749cDdCD78d6cb90d573C8      │
│                                                          │
│  - ERC20 + Permit + Burnable + Capped + Pausable       │
│  - Roles: DEFAULT_ADMIN_ROLE, MINTER_ROLE, PAUSER_ROLE │
└─────────────────────────────────────────────────────────┘
                    │                    │
                    │                    │
        ┌───────────┘                    └───────────┐
        │                                            │
        ▼                                            ▼
┌──────────────────┐                    ┌──────────────────┐
│ JobsTokenStaking │                    │ JobsTokenVesting │
│ 0xbbF9db5E...   │                    │ 0xb47fC1F05...  │
│                  │                    │                  │
│ - Stake/Unstake  │                    │ - CreateVesting  │
│ - Claim Rewards  │                    │ - Claim Vested   │
│ - Prefunded Pool │                    │ - Cliff Period   │
└──────────────────┘                    └──────────────────┘
```

---

## 1. JobsTokenFullV2 (ERC20 Token)

### 📋 Osnovne Informacije

- **Name**: Jobs Token
- **Symbol**: JOBS
- **Decimals**: 18
- **Cap**: 1,000,000,000 JOBS (1B)
- **Features**: ERC20 + Permit + Burnable + Capped + Pausable + AccessControl

### 🔐 Roles

```solidity
bytes32 public constant DEFAULT_ADMIN_ROLE = 0x0000...0000;
bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
```

### 📊 Funkcije

#### User Funkcije
- `transfer(address to, uint256 amount)` - Transfer tokena
- `approve(address spender, uint256 amount)` - Approve za spending
- `transferFrom(address from, address to, uint256 amount)` - TransferFrom
- `burn(uint256 amount)` - Spali svoje tokene

#### Admin Funkcije
- `mint(address to, uint256 amount)` - Mint novih tokena (MINTER_ROLE)
- `pause()` - Pause sve transfer/mint/burn (PAUSER_ROLE)
- `unpause()` - Unpause (PAUSER_ROLE)

### 🧪 Cast Komande

```bash
# Osnovne informacije
cast call $TOKEN_ADDRESS "name()(string)" --rpc-url $RPC_URL
cast call $TOKEN_ADDRESS "symbol()(string)" --rpc-url $RPC_URL
cast call $TOKEN_ADDRESS "totalSupply()(uint256)" --rpc-url $RPC_URL
cast call $TOKEN_ADDRESS "cap()(uint256)" --rpc-url $RPC_URL
cast call $TOKEN_ADDRESS "paused()(bool)" --rpc-url $RPC_URL

# Balances
cast call $TOKEN_ADDRESS "balanceOf(address)(uint256)" $WALLET --rpc-url $RPC_URL

# Roles
DEFAULT_ADMIN_ROLE=0x0000000000000000000000000000000000000000000000000000000000000000
MINTER_ROLE=$(cast keccak "MINTER_ROLE")
PAUSER_ROLE=$(cast keccak "PAUSER_ROLE")

cast call $TOKEN_ADDRESS "hasRole(bytes32,address)(bool)" $DEFAULT_ADMIN_ROLE $ADMIN_ADDRESS --rpc-url $RPC_URL
cast call $TOKEN_ADDRESS "hasRole(bytes32,address)(bool)" $MINTER_ROLE $ADMIN_ADDRESS --rpc-url $RPC_URL
cast call $TOKEN_ADDRESS "hasRole(bytes32,address)(bool)" $PAUSER_ROLE $ADMIN_ADDRESS --rpc-url $RPC_URL

# Admin akcije
cast send $TOKEN_ADDRESS "mint(address,uint256)" $ADMIN_ADDRESS 1000000000000000000000 \
  --private-key $ADMIN_PRIVATE_KEY --rpc-url $RPC_URL

cast send $TOKEN_ADDRESS "pause()" --private-key $ADMIN_PRIVATE_KEY --rpc-url $RPC_URL
cast send $TOKEN_ADDRESS "unpause()" --private-key $ADMIN_PRIVATE_KEY --rpc-url $RPC_URL
```

---

## 2. JobsTokenStaking

### 📋 Osnovne Informacije

- **Model**: Prefunded Pool (admin prefund-uje rewards)
- **Rewards Token**: Isti kao staking token (JOBS)
- **Rewards Duration**: 7 dana (604800 sekundi) - može se promijeniti
- **Accounting**: MasterChef-style accumulator (O(1) updates)

### 🔐 Roles

```solidity
bytes32 public constant DEFAULT_ADMIN_ROLE = 0x0000...0000;
bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
```

### 📊 State Variables

```solidity
IERC20 public immutable stakingToken;        // Token koji se stakea
uint256 public rewardsDuration;              // Trajanje reward perioda (default: 7 dana)
uint256 public periodFinish;                 // Kada završava trenutni period
uint256 public rewardRatePerSecond;         // Reward rate (tokens/sec)
uint256 public accRewardPerShare;            // Accumulated reward per share (scaled 1e18)
uint256 public totalStaked;                  // Ukupno stakano
mapping(address => uint256) public balanceOf; // Koliko user ima stakano
mapping(address => uint256) public rewardDebt; // Bookkeeping za rewards
```

### 📊 Funkcije

#### User Funkcije
- `stake(uint256 amount)` - Stake tokens (zahtijeva approve)
- `unstake(uint256 amount)` - Unstake tokens (automatski claima rewards)
- `claim()` - Claim pending rewards
- `pendingRewards(address user)` - View: koliko rewards možeš claimati
- `emergencyWithdraw()` - Hitno povlačenje (forfeits rewards)

#### Admin/Manager Funkcije
- `notifyRewardAmount(uint256 rewardAmount)` - Aktivira rewards (MANAGER_ROLE)
- `setRewardsDuration(uint256 newDuration)` - Postavi duration (MANAGER_ROLE)
- `pause()` - Pause user akcije (PAUSER_ROLE)
- `unpause()` - Unpause (PAUSER_ROLE)
- `rescueERC20(address token, address to, uint256 amount)` - Rescue non-staking tokens (DEFAULT_ADMIN_ROLE)

### 🔄 Flow

#### 1. Admin Setup (jednom)
```bash
# 1. Transfer reward tokens u staking kontrakt
cast send $TOKEN_ADDRESS "transfer(address,uint256)" \
  $STAKING_ADDRESS 1000000000000000000000 \
  --private-key $ADMIN_PRIVATE_KEY --rpc-url $RPC_URL

# 2. Aktiviraj rewards
cast send $STAKING_ADDRESS "notifyRewardAmount(uint256)" \
  1000000000000000000000 \
  --private-key $ADMIN_PRIVATE_KEY --rpc-url $RPC_URL
```

#### 2. User Staking
```bash
# 1. Approve
cast send $TOKEN_ADDRESS "approve(address,uint256)" \
  $STAKING_ADDRESS 1000000000000000000000 \
  --private-key $WALLET_PRIVATE_KEY --rpc-url $RPC_URL

# 2. Stake
cast send $STAKING_ADDRESS "stake(uint256)" \
  1000000000000000000000 \
  --private-key $WALLET_PRIVATE_KEY --rpc-url $RPC_URL

# 3. Provjeri pending rewards
cast call $STAKING_ADDRESS "pendingRewards(address)(uint256)" $WALLET --rpc-url $RPC_URL

# 4. Claim rewards
cast send $STAKING_ADDRESS "claim()" \
  --private-key $WALLET_PRIVATE_KEY --rpc-url $RPC_URL

# 5. Unstake (automatski claima rewards)
cast send $STAKING_ADDRESS "unstake(uint256)" \
  1000000000000000000000 \
  --private-key $WALLET_PRIVATE_KEY --rpc-url $RPC_URL
```

### 🧪 Cast Komande

```bash
# Osnovne informacije
cast call $STAKING_ADDRESS "stakingToken()(address)" --rpc-url $RPC_URL
cast call $STAKING_ADDRESS "totalStaked()(uint256)" --rpc-url $RPC_URL
cast call $STAKING_ADDRESS "rewardsDuration()(uint256)" --rpc-url $RPC_URL
cast call $STAKING_ADDRESS "periodFinish()(uint256)" --rpc-url $RPC_URL
cast call $STAKING_ADDRESS "rewardRatePerSecond()(uint256)" --rpc-url $RPC_URL
cast call $STAKING_ADDRESS "paused()(bool)" --rpc-url $RPC_URL

# User info
cast call $STAKING_ADDRESS "balanceOf(address)(uint256)" $WALLET --rpc-url $RPC_URL
cast call $STAKING_ADDRESS "pendingRewards(address)(uint256)" $WALLET --rpc-url $RPC_URL

# Roles
MANAGER_ROLE=$(cast keccak "MANAGER_ROLE")
cast call $STAKING_ADDRESS "hasRole(bytes32,address)(bool)" $DEFAULT_ADMIN_ROLE $ADMIN_ADDRESS --rpc-url $RPC_URL
cast call $STAKING_ADDRESS "hasRole(bytes32,address)(bool)" $MANAGER_ROLE $ADMIN_ADDRESS --rpc-url $RPC_URL
cast call $STAKING_ADDRESS "hasRole(bytes32,address)(bool)" $PAUSER_ROLE $ADMIN_ADDRESS --rpc-url $RPC_URL
```

---

## 3. JobsTokenVestingERC20

### 📋 Osnovne Informacije

- **Model**: Time-locked token distribution
- **Cliff Period**: Period prije kojeg korisnik ne može claimati ništa
- **Vesting Duration**: Period u kojem se tokene vestaju linearno
- **Revocable**: Admin može revoke-ati vesting (vraća ne-vestani dio)

### 🔐 Roles

```solidity
bytes32 public constant DEFAULT_ADMIN_ROLE = 0x0000...0000;
bytes32 public constant VESTING_ADMIN_ROLE = keccak256("VESTING_ADMIN_ROLE");
```

### 📊 Struct

```solidity
struct Vesting {
    uint128 total;      // Ukupno tokena u vestingu
    uint128 claimed;    // Koliko je već claimano
    uint64  start;      // Start timestamp
    uint64  cliff;      // Cliff timestamp (prije ovoga = 0 vested)
    uint64  duration;   // Vesting duration (sekunde)
    bool    revoked;    // Je li revoked
}
```

### 📊 Funkcije

#### User Funkcije
- `claim(uint256 id)` - Claim vested tokene za vesting #id
- `vestedAmount(address beneficiary, uint256 id)` - View: koliko je vested
- `vestingCount(address beneficiary)` - View: koliko vestinga ima korisnik
- `vestings(address beneficiary, uint256 id)` - View: vesting struct

#### Admin Funkcije
- `createVesting(address beneficiary, uint256 total, uint256 start, uint256 cliffDuration, uint256 duration)` - Kreira vesting (VESTING_ADMIN_ROLE)
- `revoke(address beneficiary, uint256 id)` - Revoke vesting (VESTING_ADMIN_ROLE)

### 🔄 Flow

#### 1. Admin Kreira Vesting
```bash
# 1. Approve vesting kontraktu
cast send $TOKEN_ADDRESS "approve(address,uint256)" \
  $VESTING_ADDRESS 1000000000000000000000 \
  --private-key $ADMIN_PRIVATE_KEY --rpc-url $RPC_URL

# 2. Kreiraj vesting
CURRENT_TIME=$(cast block latest --rpc-url $RPC_URL | grep timestamp | awk '{print $2}')
CLIFF_DURATION=2592000   # 30 dana
DURATION=7776000         # 90 dana

cast send $VESTING_ADDRESS "createVesting(address,uint256,uint256,uint256,uint256)" \
  $WALLET \
  1000000000000000000000 \
  $CURRENT_TIME \
  $CLIFF_DURATION \
  $DURATION \
  --private-key $ADMIN_PRIVATE_KEY --rpc-url $RPC_URL
```

#### 2. User Claim
```bash
# Provjeri vested amount
cast call $VESTING_ADDRESS "vestedAmount(address,uint256)(uint256)" $WALLET 0 --rpc-url $RPC_URL

# Claim (samo ako je vested > 0)
cast send $VESTING_ADDRESS "claim(uint256)" 0 \
  --private-key $WALLET_PRIVATE_KEY --rpc-url $RPC_URL
```

### 🧪 Cast Komande

```bash
# Osnovne informacije
cast call $VESTING_ADDRESS "token()(address)" --rpc-url $RPC_URL

# Vesting info
cast call $VESTING_ADDRESS "vestingCount(address)(uint256)" $WALLET --rpc-url $RPC_URL
cast call $VESTING_ADDRESS "vestings(address,uint256)(uint128,uint128,uint64,uint64,uint64,bool)" $WALLET 0 --rpc-url $RPC_URL
cast call $VESTING_ADDRESS "vestedAmount(address,uint256)(uint256)" $WALLET 0 --rpc-url $RPC_URL

# Roles
VESTING_ADMIN_ROLE=$(cast keccak "VESTING_ADMIN_ROLE")
cast call $VESTING_ADDRESS "hasRole(bytes32,address)(bool)" $DEFAULT_ADMIN_ROLE $ADMIN_ADDRESS --rpc-url $RPC_URL
cast call $VESTING_ADDRESS "hasRole(bytes32,address)(bool)" $VESTING_ADMIN_ROLE $ADMIN_ADDRESS --rpc-url $RPC_URL
```

---

## 4. Staking vs Vesting

### 📊 Usporedba

| | **STAKING** | **VESTING** |
|---|---|---|
| **Tko odlučuje** | Korisnik (dobrovoljno) | Admin (kreira za korisnika) |
| **Dobivaš rewards** | ✅ DA (bonus tokene) | ❌ NE (samo svoje tokene) |
| **Možeš povući kad god** | ✅ DA | ❌ NE (mora proći cliff) |
| **Principal** | Tvoji tokeni | Admin ti daje tokene |
| **Rezultat** | Principal + Rewards | Samo principal (postepeno) |
| **Cilj** | Yield/rewards program | Postepeno oslobađanje |

### 🎯 Kada koristiti

**Staking:**
- Incentiviziranje holdinga tokena
- Yield farming programi
- Distribucija rewards korisnicima

**Vesting:**
- Team token allocation
- Investor token distribution
- Advisors / partners grants
- Sprječavanje "dump-a"

---

## 5. Cast Komande

### 🔍 Provjera Statusa

```bash
# Postavi environment varijable
source .env

# Role hashes
DEFAULT_ADMIN_ROLE=0x0000000000000000000000000000000000000000000000000000000000000000
MINTER_ROLE=$(cast keccak "MINTER_ROLE")
PAUSER_ROLE=$(cast keccak "PAUSER_ROLE")
MANAGER_ROLE=$(cast keccak "MANAGER_ROLE")
VESTING_ADMIN_ROLE=$(cast keccak "VESTING_ADMIN_ROLE")

# ============================================================
# TOKEN PROVJERE
# ============================================================
echo "=== TOKEN ==="
cast call $TOKEN_ADDRESS "name()(string)" --rpc-url $RPC_URL
cast call $TOKEN_ADDRESS "symbol()(string)" --rpc-url $RPC_URL
cast call $TOKEN_ADDRESS "totalSupply()(uint256)" --rpc-url $RPC_URL
cast call $TOKEN_ADDRESS "cap()(uint256)" --rpc-url $RPC_URL
cast call $TOKEN_ADDRESS "paused()(bool)" --rpc-url $RPC_URL
cast call $TOKEN_ADDRESS "balanceOf(address)(uint256)" $WALLET --rpc-url $RPC_URL

# ============================================================
# STAKING PROVJERE
# ============================================================
echo "=== STAKING ==="
cast call $STAKING_ADDRESS "stakingToken()(address)" --rpc-url $RPC_URL
cast call $STAKING_ADDRESS "totalStaked()(uint256)" --rpc-url $RPC_URL
cast call $STAKING_ADDRESS "rewardsDuration()(uint256)" --rpc-url $RPC_URL
cast call $STAKING_ADDRESS "periodFinish()(uint256)" --rpc-url $RPC_URL
cast call $STAKING_ADDRESS "rewardRatePerSecond()(uint256)" --rpc-url $RPC_URL
cast call $STAKING_ADDRESS "balanceOf(address)(uint256)" $WALLET --rpc-url $RPC_URL
cast call $STAKING_ADDRESS "pendingRewards(address)(uint256)" $WALLET --rpc-url $RPC_URL

# ============================================================
# VESTING PROVJERE
# ============================================================
echo "=== VESTING ==="
cast call $VESTING_ADDRESS "token()(address)" --rpc-url $RPC_URL
cast call $VESTING_ADDRESS "vestingCount(address)(uint256)" $WALLET --rpc-url $RPC_URL
cast call $VESTING_ADDRESS "vestedAmount(address,uint256)(uint256)" $WALLET 0 --rpc-url $RPC_URL
```

---

## 6. Deploy Flow

### 📋 Redoslijed Deploy-a

1. **Deploy Token** (`DeployJobsTokenFullV2.s.sol`)
   ```bash
   forge script src/tokens/script/deploy/DeployJobsTokenFullV2.s.sol:DeployJobsTokenFullV2 \
     --rpc-url $RPC_URL --broadcast -vvv
   ```

2. **Deploy Staking** (`DeployJobsTokenStaking.s.sol`)
   ```bash
   forge script src/tokens/script/deploy/DeployJobsTokenStaking.s.sol:DeployJobsTokenStaking \
     --rpc-url $RPC_URL --broadcast -vvv
   ```

3. **Deploy Vesting** (`DeployJobsTokenVestingERC20.s.sol`)
   ```bash
   forge script src/tokens/script/deploy/DeployJobsTokenVestingERC20.s.sol:DeployJobsTokenVestingERC20 \
     --rpc-url $RPC_URL --broadcast -vvv
   ```

4. **Wire Staking** (`WireJobsERC20.s.sol`)
   ```bash
   forge script src/tokens/script/deploy/WireJobsERC20.s.sol:WireJobsERC20 \
     --rpc-url $RPC_URL --broadcast -vvv
   ```

---

## 7. Status Provjere

### ✅ Checklist

- [ ] Token deployan i unpaused
- [ ] Admin ima sve role (DEFAULT_ADMIN, MINTER, PAUSER)
- [ ] Staking deployan i povezan s tokenom
- [ ] Staking admin ima sve role (DEFAULT_ADMIN, MANAGER, PAUSER)
- [ ] Rewards prefund-ovani i aktivirani
- [ ] Vesting deployan i povezan s tokenom
- [ ] Vesting admin ima sve role (DEFAULT_ADMIN, VESTING_ADMIN)

### 🔍 Quick Status Check

```bash
# Provjeri sve kontrakte odjednom
echo "Token:"
cast call $TOKEN_ADDRESS "name()(string)" --rpc-url $RPC_URL
cast call $TOKEN_ADDRESS "paused()(bool)" --rpc-url $RPC_URL

echo "Staking:"
cast call $STAKING_ADDRESS "stakingToken()(address)" --rpc-url $RPC_URL
cast call $STAKING_ADDRESS "totalStaked()(uint256)" --rpc-url $RPC_URL
cast call $STAKING_ADDRESS "paused()(bool)" --rpc-url $RPC_URL

echo "Vesting:"
cast call $VESTING_ADDRESS "token()(address)" --rpc-url $RPC_URL
cast call $VESTING_ADDRESS "vestingCount(address)(uint256)" $WALLET --rpc-url $RPC_URL
```

---

## 📝 Notes

- **Staking**: Koristi prefunded pool model - admin mora prefund-ovati rewards prije aktivacije
- **Vesting**: Cliff period mora proći prije claimanja
- **Token**: Pausable - admin može pause-ati u slučaju emergency
- **Roles**: Svi kontrakte koriste AccessControl za upravljanje permisijama

---

**Last Updated**: $(date)

