# 🔗 Provjera Povezanosti Kontrakata

## 📋 Pregled Kontrakata

### 1. **JobsTokenFullV2** (ERC20 Token)
- **Svrha:** Glavni ERC20 token
- **Povezan sa:**
  - ✅ `JobsTokenStaking` (staking token)
  - ✅ `JobsTokenVestingERC20` (vesting token)

---

### 2. **JobsTokenStaking** (Staking Kontrakt)
- **Svrha:** Staking kontrakt gdje korisnici stakeaju tokene
- **Token:** `stakingToken` (immutable) - mora biti `JobsTokenFullV2`
- **Reward Token:** Isti kao staking token (same-token model)
- **Povezan sa:**
  - ✅ `JobsTokenFullV2` (staking token i reward token)

**Constructor:**
```solidity
constructor(address stakingToken_, address rewardToken_, address admin_)
```

**Provjera:**
- ✅ `stakingToken_` mora biti adresa `JobsTokenFullV2`
- ✅ `rewardToken_` mora biti ista adresa kao `stakingToken_` (same-token model)
- ✅ `admin_` dobiva `DEFAULT_ADMIN_ROLE` i `MANAGER_ROLE`

---

### 3. **JobsTokenVestingERC20** (Vesting Kontrakt)
- **Svrha:** Vesting kontrakt gdje se tokeni vestaju
- **Token:** `token` (immutable) - mora biti `JobsTokenFullV2`
- **Povezan sa:**
  - ✅ `JobsTokenFullV2` (vesting token)

**Constructor:**
```solidity
constructor(address token_, address admin_)
```

**Provjera:**
- ✅ `token_` mora biti adresa `JobsTokenFullV2`
- ✅ `admin_` dobiva `DEFAULT_ADMIN_ROLE` i `VESTING_ADMIN_ROLE`

---

## 🔍 Detaljna Provjera

### 1. Deployment Skripte

#### DeployJobsTokenStaking.s.sol
```solidity
staking = new JobsTokenStaking(address(token), address(token), admin);
```

**Provjera:**
- ✅ `stakingToken_` = `address(token)` (JobsTokenFullV2)
- ✅ `rewardToken_` = `address(token)` (isti token - same-token model)
- ✅ `admin_` = `admin` (dobiva role-ove)

**Status:** ✅ **ISPRAVNO**

---

#### DeployJobsTokenVestingERC20.s.sol
```solidity
vesting = new JobsTokenVestingERC20(address(token), admin);
```

**Provjera:**
- ✅ `token_` = `address(token)` (JobsTokenFullV2)
- ✅ `admin_` = `admin` (dobiva role-ove)

**Status:** ✅ **ISPRAVNO**

---

### 2. Wire Skripta

#### WireJobsERC20.s.sol
```solidity
address token = vm.envAddress("TOKEN_ADDRESS");
address staking = vm.envAddress("STAKING_ADDRESS");

// Prefund rewards
IERC20(token).transfer(staking, rewardAmount);
IStakingManager(staking).notifyRewardAmount(rewardAmount);
```

**Provjera:**
- ✅ Koristi `TOKEN_ADDRESS` i `STAKING_ADDRESS` iz env varijabli
- ✅ Transferira tokene u staking kontrakt (prefund)
- ✅ Poziva `notifyRewardAmount()` da aktivira rewards

**Status:** ✅ **ISPRAVNO**

---

## ✅ Provjera Povezanosti

### Tokens → Staking
```
JobsTokenFullV2 → JobsTokenStaking
  - stakingToken = JobsTokenFullV2 ✅
  - rewardToken = JobsTokenFullV2 ✅ (same-token model)
```

### Tokens → Vesting
```
JobsTokenFullV2 → JobsTokenVestingERC20
  - token = JobsTokenFullV2 ✅
```

### Role-ovi

#### JobsTokenStaking
- ✅ `DEFAULT_ADMIN_ROLE` → `admin`
- ✅ `MANAGER_ROLE` → `admin` (za `notifyRewardAmount`, `setRewardsDuration`)
- ✅ `PAUSER_ROLE` → može biti postavljen (za pause/unpause)

#### JobsTokenVestingERC20
- ✅ `DEFAULT_ADMIN_ROLE` → `admin`
- ✅ `VESTING_ADMIN_ROLE` → `admin` (za `createVesting`)

#### JobsTokenFullV2
- ✅ `DEFAULT_ADMIN_ROLE` → `admin`
- ✅ `MINTER_ROLE` → može biti postavljen (za mint)
- ✅ `PAUSER_ROLE` → može biti postavljen (za pause/unpause)

---

## 🔧 Provjera Funkcionalnosti

### Staking Flow
1. ✅ Korisnik ima `JobsTokenFullV2` tokene
2. ✅ Korisnik poziva `approve(staking, amount)` na token kontraktu
3. ✅ Korisnik poziva `stake(amount)` na staking kontraktu
4. ✅ Staking kontrakt poziva `transferFrom(user, staking, amount)` na token kontraktu
5. ✅ Tokens se prebacuju u staking kontrakt
6. ✅ Korisnik može claimati rewards (isti token)

**Status:** ✅ **ISPRAVNO**

---

### Vesting Flow
1. ✅ Admin ima `JobsTokenFullV2` tokene
2. ✅ Admin poziva `approve(vesting, amount)` na token kontraktu
3. ✅ Admin poziva `createVesting(beneficiary, total, start, cliff, duration)` na vesting kontraktu
4. ✅ Vesting kontrakt poziva `transferFrom(admin, vesting, total)` na token kontraktu
5. ✅ Tokens se prebacuju u vesting kontrakt
6. ✅ Beneficiary može claimati vested tokene

**Status:** ✅ **ISPRAVNO**

---

## 🎯 Zaključak

### ✅ Sve je Ispravno Povezano!

1. **Token → Staking:**
   - ✅ `stakingToken` = `JobsTokenFullV2`
   - ✅ `rewardToken` = `JobsTokenFullV2` (same-token model)
   - ✅ Role-ovi su ispravno postavljeni

2. **Token → Vesting:**
   - ✅ `token` = `JobsTokenFullV2`
   - ✅ Role-ovi su ispravno postavljeni

3. **Deployment:**
   - ✅ Deployment skripte koriste ispravne adrese
   - ✅ Wire skripta ispravno povezuje kontrakte

4. **Funkcionalnost:**
   - ✅ Staking flow radi ispravno
   - ✅ Vesting flow radi ispravno

---

## 📝 Preporuke

### 1. Provjeri Deployed Adrese

Ako su kontrakti već deployani, provjeri da su adrese ispravne:

```bash
# Provjeri staking token
cast call $STAKING_ADDRESS "stakingToken()(address)"

# Provjeri vesting token
cast call $VESTING_ADDRESS "token()(address)"

# Provjeri da su iste adrese
# Očekivano: obje vraćaju $TOKEN_ADDRESS
```

### 2. Provjeri Role-ove

```bash
# Provjeri admin role u staking
cast call $STAKING_ADDRESS "hasRole(bytes32,address)(bool)" \
  $(cast keccak "DEFAULT_ADMIN_ROLE()") $ADMIN_ADDRESS

# Provjeri manager role u staking
cast call $STAKING_ADDRESS "hasRole(bytes32,address)(bool)" \
  $(cast keccak "MANAGER_ROLE()") $ADMIN_ADDRESS

# Provjeri vesting admin role
cast call $VESTING_ADDRESS "hasRole(bytes32,address)(bool)" \
  $(cast keccak "VESTING_ADMIN_ROLE()") $ADMIN_ADDRESS
```

### 3. Provjeri Allowance

```bash
# Provjeri allowance za staking
cast call $TOKEN_ADDRESS "allowance(address,address)(uint256)" \
  $USER_ADDRESS $STAKING_ADDRESS

# Provjeri allowance za vesting
cast call $TOKEN_ADDRESS "allowance(address,address)(uint256)" \
  $ADMIN_ADDRESS $VESTING_ADDRESS
```

---

## ✅ Finalni Status

**Svi kontrakti su ispravno povezani! 🎉**

- ✅ Token → Staking: Ispravno
- ✅ Token → Vesting: Ispravno
- ✅ Role-ovi: Ispravno postavljeni
- ✅ Deployment: Ispravno
- ✅ Funkcionalnost: Ispravno

**Kontrakti su spremni za korištenje! 🚀**

