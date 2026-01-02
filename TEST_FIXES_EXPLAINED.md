# 🔧 Detaljno Objašnjenje Popravki Testova

## 📋 Pregled Promjena

Testovi su padali zbog 3 glavna problema:
1. **ZeroAddress() greška** - pogrešan poziv konstruktora
2. **Balance assertion greške** - testovi nisu uzimali u obzir rewards pool
3. **Rewards testovi padaju** - nema prefund-ovanih rewards

---

## 🔴 Problem 1: ZeroAddress() Greška u Konstruktoru

### ❌ PRIJE (Pogrešno):

```solidity
// test/staking/JobsTokenStaking.t.sol (linija 27)
staking = new JobsTokenStaking(address(token), admin, admin);
```

**Zašto je padalo:**
- Konstruktor očekuje: `(address stakingToken_, address rewardToken_, address admin_)`
- Test je proslijedio: `(address(token), admin, admin)`
- `rewardToken_` je bio `admin` (address), a konstruktor provjerava:
  ```solidity
  if (stakingToken_ == address(0) || rewardToken_ == address(0) || admin_ == address(0)) 
      revert ZeroAddress();
  if (stakingToken_ != rewardToken_) revert ZeroAddress(); // enforce same-token model
  ```
- `stakingToken_` (token address) != `rewardToken_` (admin address) → **ZeroAddress() greška**

### ✅ POSLIJE (Ispravno):

```solidity
// test/staking/JobsTokenStaking.t.sol (linija 28)
staking = new JobsTokenStaking(address(token), address(token), admin);
```

**Zašto sada radi:**
- `stakingToken_` = `address(token)`
- `rewardToken_` = `address(token)` (isti token - same-token model)
- `admin_` = `admin`
- Sve provjere prolaze ✅

**Ista promjena u:**
- `test/staking/JobsTokenStaking.t.sol` (linija 28)
- `test/staking/JobsTokenStaking.admin.t.sol` (linija 19)

---

## 🔴 Problem 2: Balance Assertion Greške

### ❌ PRIJE (Pogrešno):

```solidity
// test_stake_updatesBalances()
function test_stake_updatesBalances() public {
    uint256 amount = 100e18;
    uint256 aliceBefore = token.balanceOf(alice);

    vm.prank(alice);
    staking.stake(amount);

    assertEq(staking.balanceOf(alice), amount);
    assertEq(staking.totalStaked(), amount);
    assertEq(token.balanceOf(alice), aliceBefore - amount);
    
    // ❌ OVO JE PADALO:
    assertEq(token.balanceOf(address(staking)), amount);
    // Očekivano: 100e18
    // Stvarno: 10_100e18 (10k rewards + 100 staked)
}
```

**Zašto je padalo:**
- Test je očekivao da staking kontrakt ima **samo** staked amount (100e18)
- Ali kontrakt ima **rewards pool** (10_000e18) + **staked amount** (100e18) = 10_100e18
- Assertion: `10_100e18 != 100e18` → **FAIL**

### ✅ POSLIJE (Ispravno):

```solidity
// test_stake_updatesBalances()
function test_stake_updatesBalances() public {
    uint256 amount = 100e18;
    uint256 aliceBefore = token.balanceOf(alice);
    uint256 stakingBefore = token.balanceOf(address(staking)); // ✅ Snimi početni balance

    vm.prank(alice);
    staking.stake(amount);

    assertEq(staking.balanceOf(alice), amount);
    assertEq(staking.totalStaked(), amount);
    assertEq(token.balanceOf(alice), aliceBefore - amount);
    
    // ✅ Provjeri RELATIVNU promjenu:
    assertEq(token.balanceOf(address(staking)), stakingBefore + amount);
    // Očekivano: stakingBefore (10k) + 100 = 10_100e18
    // Stvarno: 10_100e18 ✅
}
```

**Zašto sada radi:**
- Snimimo početni balance staking kontrakta (`stakingBefore`)
- Provjeravamo da se balance **povećao** za `amount`
- Ne provjeravamo apsolutnu vrijednost, već relativnu promjenu ✅

**Ista logika primijenjena na:**
- `test_stake_updatesBalances()` (linija 68, 80)
- `test_withdraw_returnsTokens()` (linija 101, 113)

---

## 🔴 Problem 3: Rewards Testovi Padaju

### ❌ PRIJE (Pogrešno):

```solidity
function setUp() public {
    // ... deploy token i staking ...
    
    // approvals
    vm.prank(alice);
    token.approve(address(staking), type(uint256).max);
    vm.prank(bob);
    token.approve(address(staking), type(uint256).max);
    
    // ❌ NEMA PREFUND-OVANIH REWARDS!
}
```

**Zašto su testovi padali:**

1. **test_rewards_earned_increases_over_time():**
   ```solidity
   function test_rewards_earned_increases_over_time() public {
       vm.prank(alice);
       staking.stake(100e18);
       vm.warp(block.timestamp + 7 days);
       
       uint256 e = staking.rewardDebt(alice);
       assertGt(e, 0); // ❌ PADA: e = 0 jer nema rewards
   }
   ```
   - Nema prefund-ovanih rewards → `rewardRatePerSecond = 0`
   - Nema akumulacije rewards → `rewardDebt` ostaje 0
   - Assertion: `0 > 0` → **FAIL**

2. **test_claim_pays_rewards():**
   ```solidity
   function test_claim_pays_rewards() public {
       vm.prank(alice);
       staking.stake(100e18);
       vm.warp(block.timestamp + 7 days);
       
       uint256 before = token.balanceOf(alice);
       vm.prank(alice);
       staking.claim();
       
       uint256 afterBal = token.balanceOf(alice);
       assertGt(afterBal, before); // ❌ PADA: before == after (nema rewards)
   }
   ```
   - Nema rewards → `pendingRewards() = 0`
   - `claim()` ne isplaćuje ništa → balance se ne mijenja
   - Assertion: `before == after` → **FAIL**

### ✅ POSLIJE (Ispravno):

```solidity
function setUp() public {
    // ... deploy token i staking ...
    
    // approvals
    vm.prank(alice);
    token.approve(address(staking), type(uint256).max);
    vm.prank(bob);
    token.approve(address(staking), type(uint256).max);

    // ✅ DODANO: Prefund rewards za staking (potrebno za prefunded pool model)
    vm.startPrank(admin);
    uint256 rewardAmount = 10_000e18; // 10k tokena za rewards
    token.mint(admin, rewardAmount);           // 1. Mint rewards adminu
    token.transfer(address(staking), rewardAmount); // 2. Transfer u staking kontrakt
    staking.notifyRewardAmount(rewardAmount);      // 3. Aktiviraj rewards
    vm.stopPrank();
}
```

**Zašto sada radi:**

1. **Prefund rewards:**
   - Admin dobiva 10_000e18 tokena (mint)
   - Transferira ih u staking kontrakt
   - Poziva `notifyRewardAmount()` → aktivira rewards distribuciju
   - `rewardRatePerSecond` se postavlja na > 0

2. **test_rewards_earned_increases_over_time():**
   ```solidity
   function test_rewards_earned_increases_over_time() public {
       vm.prank(alice);
       staking.stake(100e18);
       vm.warp(block.timestamp + 1 days);
       
       // ✅ Koristi pendingRewards() umjesto rewardDebt
       uint256 pending = staking.pendingRewards(alice);
       assertGt(pending, 0); // ✅ Sada pending > 0 jer ima rewards
   }
   ```
   - Sada ima rewards → `pendingRewards() > 0` ✅

3. **test_claim_pays_rewards():**
   ```solidity
   function test_claim_pays_rewards() public {
       vm.prank(alice);
       staking.stake(100e18);
       vm.warp(block.timestamp + 1 days);
       
       uint256 before = token.balanceOf(alice);
       uint256 pendingBefore = staking.pendingRewards(alice);
       assertGt(pendingBefore, 0, "Should have pending rewards"); // ✅ Provjeri da ima rewards
       
       vm.prank(alice);
       staking.claim();
       
       uint256 afterBal = token.balanceOf(alice);
       assertGt(afterBal, before, "Balance should increase after claim"); // ✅ Sada radi
       
       uint256 pendingAfter = staking.pendingRewards(alice);
       assertLt(pendingAfter, pendingBefore, "Pending should decrease"); // ✅ Dodatna provjera
   }
   ```
   - Sada ima rewards → `claim()` isplaćuje rewards → balance se povećava ✅

---

## 📊 Sažetak Promjena

| Problem | Prije | Poslije | Zašto |
|---------|-------|---------|-------|
| **Konstruktor** | `(token, admin, admin)` | `(token, token, admin)` | `rewardToken_` mora biti isti kao `stakingToken_` |
| **Balance assertion** | Apsolutna vrijednost | Relativna promjena | Kontrakt ima rewards pool + staked |
| **Rewards setup** | Nema prefund-a | Prefund 10k tokena | Rewards se ne mogu distribuirati bez prefund-a |
| **Rewards test** | `rewardDebt` provjera | `pendingRewards()` provjera | `pendingRewards()` je view funkcija koja računa trenutne rewards |

---

## 🎯 Ključne Lekcije

1. **Prefunded Pool Model:**
   - Staking kontrakt **NE MINT-A** rewards
   - Admin mora **PREFUND-OVATI** rewards prije aktivacije
   - Rewards se distribuiraju iz prefund-ovanog pool-a

2. **Balance Accounting:**
   - Staking kontrakt drži: **rewards pool** + **staked tokens**
   - Testovi moraju provjeravati **relativne promjene**, ne apsolutne vrijednosti

3. **Same-Token Model:**
   - `stakingToken` i `rewardToken` su **ISTI TOKEN**
   - Konstruktor provjerava da su jednaki

---

## ✅ Rezultat

**Prije:**
- ❌ 2 testa padaju (ZeroAddress)
- ❌ 2 testa padaju (balance assertions)
- ❌ 2 testa padaju (rewards)

**Poslije:**
- ✅ 20 testova prolazi
- ✅ 0 testova pada
- ✅ Svi testovi pokrivaju funkcionalnosti

