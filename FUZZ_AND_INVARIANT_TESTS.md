# 🧪 Fuzz & Invariant Testovi - Kompletna Dokumentacija

## 📚 Sadržaj

1. [Uvod](#uvod)
2. [Što su Fuzz Testovi?](#što-su-fuzz-testovi)
3. [Što su Invariant Testovi?](#što-su-invariant-testovi)
4. [Zašto su Važni?](#zašto-su-važni)
5. [Kako Funkcioniraju?](#kako-funkcioniraju)
6. [Pregled Testova](#pregled-testova)
7. [Kako Pokrenuti](#kako-pokrenuti)
8. [Interpretacija Rezultata](#interpretacija-rezultata)
9. [Best Practices](#best-practices)

---

## 🎯 Uvod

Fuzz i invariant testovi su napredne tehnike testiranja koje automatski generiraju nasumične inpute i provjeravaju da određena svojstva kontrakta **UVIJEK** vrijede. Ovo je kritično za sigurnost smart kontrakata jer pronalazi edge cases koje ručno pisanje testova možda ne bi pokrilo.

---

## 🔍 Što su Fuzz Testovi?

**Fuzz testovi** su testovi koji automatski generiraju **nasumične inpute** i pokreću funkcije kontrakta s tim inputima. Cilj je pronaći edge cases, overflow/underflow greške, i nepredviđene scenarije.

### Kako Funkcioniraju?

1. **Automatska generacija inputa**: Foundry automatski generira nasumične vrijednosti za parametre funkcija
2. **Bound funkcija**: Koristimo `bound()` da ograničimo inpute na razumne vrijednosti
3. **256 runs**: Svaki fuzz test se pokreće 256 puta s različitim inputima
4. **Counterexample**: Ako test padne, Foundry pokazuje točan input koji je uzrokovao grešku

### Primjer:

```solidity
/**
 * @notice Fuzz test za stake operaciju sa nasumičnim iznosima
 * @param amount Nasumični iznos za stake (boundovan na razuman range)
 */
function testFuzz_stake_updatesBalances(uint256 amount) public {
    // Bound amount na razuman range (1 wei do 100k tokens)
    amount = bound(amount, 1, 100_000e18);
    
    // Test logika...
    vm.prank(alice);
    staking.stake(amount);
    
    // Provjere...
}
```

**Što se događa:**
- Foundry generira 256 različitih vrijednosti za `amount`
- Svaka vrijednost je između 1 i 100_000e18
- Test se pokreće za svaku vrijednost
- Ako bilo koja vrijednost uzrokuje grešku, test pada i pokazuje counterexample

---

## 🛡️ Što su Invariant Testovi?

**Invariant testovi** provjeravaju da određena **svojstva kontrakta UVIJEK vrijede**, bez obzira na to koje operacije se izvode. Invarianti su uvijek istiniti uvjeti koji moraju biti zadovoljeni u svakom trenutku.

### Primjeri Invarianta:

1. **Total staked = Sum of all user balances**
   - Bez obzira koliko stake/unstake operacija se izvede, ovo mora uvijek vrijediti

2. **Contract balance >= Total staked**
   - Kontrakt mora uvijek imati dovoljno tokena za sve staked tokene

3. **Vested amount <= Total amount**
   - Vested amount ne može nikada biti veći od total amount

### Primjer:

```solidity
/**
 * @notice Invariant: totalStaked() mora uvijek biti jednak sumi svih balanceOf(user)
 */
function invariant_totalStaked_equals_sumOfBalances() public view {
    uint256 sum = 0;
    for (uint256 i = 0; i < users.length; i++) {
        sum += staking.balanceOf(users[i]);
    }
    assertEq(staking.totalStaked(), sum, "Total staked must equal sum of balances");
}
```

**Što se događa:**
- Ova funkcija se poziva **nakon svake operacije** (stake, unstake, claim, itd.)
- Ako invarijant padne, znači da je neka operacija narušila fundamentalno svojstvo kontrakta
- Ovo je kritično jer pokazuje da postoji bug u logici kontrakta

---

## ⚠️ Zašto su Važni?

### 1. **Pronalaze Edge Cases**
- Fuzz testovi automatski testiraju tisuće različitih scenarija
- Pronalaze probleme koje ručno pisanje testova ne bi pokrilo

### 2. **Overflow/Underflow Zaštita**
- Automatski pronalaze situacije gdje bi moglo doći do overflow/underflow
- Kritično za sigurnost smart kontrakata

### 3. **Invarianti Osiguravaju Konzistentnost**
- Provjeravaju da fundamentalna svojstva kontrakta uvijek vrijede
- Ako invarijant padne, znači da postoji ozbiljan bug

### 4. **Regresijsko Testiranje**
- Kada dodaješ nove funkcije, fuzz i invariant testovi automatski provjeravaju da nisi slučajno pokvario postojeću funkcionalnost

---

## 🔧 Kako Funkcioniraju?

### Fuzz Testovi - Detaljno

#### 1. Bound Funkcija

```solidity
// Bez bound - može generirati bilo koji uint256 (0 do 2^256-1)
function testFuzz_example(uint256 amount) public { ... }

// Sa bound - ograničava na razuman range
amount = bound(amount, 1, 100_000e18);
```

**Zašto koristiti bound?**
- Bez bound, testovi bi padali na ekstremnim vrijednostima koje nisu realistične
- Bound osigurava da testiramo realistične scenarije

#### 2. Multiple Parameters

```solidity
function testFuzz_multipleParams(uint256 a, uint256 b, uint256 c) public {
    a = bound(a, 1, 100);
    b = bound(b, 1, 100);
    c = bound(c, 1, 100);
    // Test logika...
}
```

Foundry generira **256 kombinacija** različitih vrijednosti za `a`, `b`, i `c`.

#### 3. Counterexample

Kada fuzz test padne, Foundry pokazuje **točan input** koji je uzrokovao grešku:

```
[FAIL: panic: arithmetic underflow or overflow (0x11)]
counterexample: calldata=0x...
args=[648, 774, 32, 255, 20506]
```

Ovo omogućava brzo debugiranje i popravljanje buga.

---

### Invariant Testovi - Detaljno

#### 1. View Funkcije

Invariant testovi su obično `view` funkcije jer samo **provjeravaju** svojstva, ne mijenjaju stanje:

```solidity
function invariant_totalStaked_equals_sumOfBalances() public view {
    // Samo provjere, nema state changes
}
```

#### 2. Pozivanje Nakon Operacija

Foundry automatski poziva invariant funkcije nakon svake state-changing operacije u testovima.

#### 3. State Tracking

Neki invariant testovi koriste storage varijable za tracking:

```solidity
uint256 public lastAccRewardPerShare;

function invariant_accRewardPerShare_onlyIncreases() public {
    uint256 current = staking.accRewardPerShare();
    assertGe(current, lastAccRewardPerShare, "Must only increase");
    lastAccRewardPerShare = current; // Update za sljedeći poziv
}
```

---

## 📊 Pregled Testova

### Staking Fuzz Testovi (13 testova)

| Test | Opis | Što Provjerava |
|------|------|----------------|
| `testFuzz_stake_updatesBalances` | Stake sa nasumičnim iznosima | Da stake radi ispravno sa bilo kojim validnim iznosom |
| `testFuzz_stake_revertsOnZero` | Stake sa zero amount | Da zero amount uvijek reverta |
| `testFuzz_stake_revertsOnInsufficientBalance` | Stake sa prevelikim iznosom | Da stake ne može prekoračiti balance |
| `testFuzz_unstake_returnsTokens` | Unstake sa nasumičnim iznosima | Da unstake radi ispravno |
| `testFuzz_unstake_revertsOnTooMuch` | Unstake sa prevelikim iznosom | Da unstake ne može prekoračiti staked balance |
| `testFuzz_pendingRewards_increasesWithTime` | Rewards sa nasumičnim vremenom | Da pending rewards raste s vremenom |
| `testFuzz_claim_paysRewards` | Claim sa nasumičnim scenarijima | Da claim isplaćuje rewards ispravno |
| `testFuzz_multipleUsers_consistency` | Multiple users sa nasumičnim iznosima | Da multi-user operacije rade ispravno |
| `testFuzz_notifyRewardAmount_works` | Notify rewards sa nasumičnim iznosima | Da notify rewards radi ispravno |
| `testFuzz_setRewardsDuration_works` | Set duration sa nasumičnim vrijednostima | Da set duration radi kada period nije aktivan |
| `testFuzz_largeAmounts_work` | Maksimalni iznosi | Da kontrakt radi sa maksimalnim vrijednostima |
| `testFuzz_minimalAmounts_work` | Minimalni iznosi (1 wei) | Da kontrakt radi sa minimalnim vrijednostima |
| `testFuzz_partialUnstake_works` | Partial unstake scenariji | Da partial unstake radi ispravno |

### Staking Invariant Testovi (10 testova)

| Invariant | Opis | Zašto je Važan |
|-----------|------|----------------|
| `invariant_totalStaked_equals_sumOfBalances` | Total staked = sum of all balances | Osigurava da accounting je konzistentan |
| `invariant_contractBalance_ge_totalStaked` | Contract balance >= total staked | Osigurava da kontrakt ima dovoljno tokena |
| `invariant_availableRewards_correct` | Available rewards = balance - staked | Osigurava da rewards se ne uzimaju iz principal |
| `invariant_accRewardPerShare_onlyIncreases` | accRewardPerShare samo raste | Osigurava da rewards accounting je monotono rastući |
| `invariant_periodFinish_ge_lastUpdateTime` | Period finish >= last update | Osigurava da reward period je validan |
| `invariant_rewardRate_consistency` | Reward rate konzistentnost | Osigurava da reward rate je ispravno postavljen |
| `invariant_userBalance_le_totalStaked` | User balance <= total staked | Osigurava da pojedinačni balance ne može biti veći od total |
| `invariant_pendingRewards_consistency` | Pending rewards konzistentnost | Osigurava da pending rewards calculation je ispravan |
| `invariant_tokenSupply_consistency` | Token supply konzistentnost | Osigurava da total supply ne prekoračuje cap |
| `invariant_no_negative_balances` | Nema negativnih balansa | Osigurava overflow protection |

### Vesting Fuzz Testovi (12 testova)

| Test | Opis | Što Provjerava |
|------|------|----------------|
| `testFuzz_createVesting_works` | Create vesting sa nasumičnim parametrima | Da create vesting radi ispravno |
| `testFuzz_createVesting_revertsOnZeroTotal` | Create vesting sa zero total | Da zero amount uvijek reverta |
| `testFuzz_createVesting_revertsOnZeroBeneficiary` | Create vesting sa zero beneficiary | Da zero address uvijek reverta |
| `testFuzz_createVesting_revertsOnCliffGreaterThanDuration` | Create vesting sa cliff > duration | Da cliff ne može biti veći od duration |
| `testFuzz_vestedAmount_increasesWithTime` | Vested amount sa nasumičnim vremenom | Da vested amount raste ispravno s vremenom |
| `testFuzz_vestedAmount_calculationConsistency` | Vested amount calculation | Da vested amount odgovara formuli |
| `testFuzz_claim_works` | Claim sa nasumičnim scenarijima | Da claim radi ispravno |
| `testFuzz_claim_revertsBeforeCliff` | Claim prije cliffa | Da claim ne može biti prije cliffa |
| `testFuzz_multipleVestings_work` | Multiple vestings za istog korisnika | Da multiple vestings rade ispravno |
| `testFuzz_largeAmounts_work` | Maksimalni iznosi | Da kontrakt radi sa maksimalnim vrijednostima |
| `testFuzz_minimalAmounts_work` | Minimalni iznosi (1 wei) | Da kontrakt radi sa minimalnim vrijednostima |
| `testFuzz_partialClaim_works` | Partial claim scenariji | Da partial claim radi ispravno |

### Vesting Invariant Testovi (10 testova)

| Invariant | Opis | Zašto je Važan |
|-----------|------|----------------|
| `invariant_vestedAmount_le_totalAmount` | Vested <= total | Osigurava da vested amount ne može biti veći od total |
| `invariant_claimed_le_vestedAmount` | Claimed <= vested | Osigurava da korisnik ne može claimati više nego što je vested |
| `invariant_claimed_le_totalAmount` | Claimed <= total | Dodatna provjera za sigurnost |
| `invariant_contractBalance_ge_unclaimed` | Contract balance >= unclaimed | Osigurava da kontrakt ima dovoljno tokena za sve unclaimed vestings |
| `invariant_vestedAmount_onlyIncreases` | Vested samo raste | Osigurava da vested amount je monotono rastući |
| `invariant_cliff_le_startPlusDuration` | Cliff <= start + duration | Osigurava da cliff je validan |
| `invariant_vestingCount_consistency` | Vesting count konzistentnost | Osigurava da count odgovara actual vestings |
| `invariant_no_negative_values` | Nema negativnih vrijednosti | Osigurava overflow protection |
| `invariant_vestedCalculation_consistency` | Vested calculation konzistentnost | Osigurava da vested calculation je ispravan |
| `invariant_tokenSupply_consistency` | Token supply konzistentnost | Osigurava da total supply ne prekoračuje cap |

---

## 🚀 Kako Pokrenuti

### Osnovne Komande

```bash
# Svi fuzz i invariant testovi
forge test --match-contract ".*(Invariant|Fuzz).*"

# Samo fuzz testovi
forge test --match-contract ".*Fuzz.*"

# Samo invariant testovi
forge test --match-contract ".*Invariant.*"

# Specifičan test
forge test --match-test "testFuzz_stake_updatesBalances"

# Sa više detalja
forge test --match-contract ".*Fuzz.*" -vvv

# Sa gas reportom
forge test --match-contract ".*Fuzz.*" --gas-report
```

### Napredne Opcije

```bash
# Povećaj broj fuzz runs (default je 256)
forge test --fuzz-runs 1000

# Pokreni samo jedan test sa više runs
forge test --match-test "testFuzz_stake_updatesBalances" --fuzz-runs 10000

# Sa seed-om za reproducibilnost
forge test --fuzz-seed 12345

# Verbose output za debugging
forge test --match-contract ".*Fuzz.*" -vvvv
```

---

## 📈 Interpretacija Rezultata

### Uspješan Test

```
[PASS] testFuzz_stake_updatesBalances(uint256) (runs: 256, μ: 103508, ~: 103223)
```

**Što znači:**
- ✅ Test je prošao
- `runs: 256` - Pokrenuto 256 puta s različitim inputima
- `μ: 103508` - Prosječan gas usage
- `~: 103223` - Median gas usage

### Neuspješan Test

```
[FAIL: panic: arithmetic underflow or overflow (0x11)]
counterexample: calldata=0x5d8358660000000000000000000000000000000000000000000000000000000000000288...
args=[648, 774, 32, 255, 20506]
testFuzz_vestedAmount_increasesWithTime(uint256,uint256,uint256,uint256,uint256) (runs: 23, μ: 139683, ~: 139826)
```

**Što znači:**
- ❌ Test je pao
- `runs: 23` - Pao na 23. pokušaju
- `counterexample` - Točan input koji je uzrokovao grešku
- `args=[648, 774, 32, 255, 20506]` - Vrijednosti parametara koje su uzrokovale grešku

**Kako popraviti:**
1. Koristi `counterexample` da reproduciraš grešku
2. Dodaj dodatne provjere u test ili kontrakt
3. Koristi `bound()` da ograničiš inpute na validne vrijednosti

---

## 💡 Best Practices

### 1. **Uvijek Koristi Bound**

```solidity
// ❌ LOŠE - može generirati ekstremne vrijednosti
function testFuzz_example(uint256 amount) public {
    staking.stake(amount);
}

// ✅ DOBRO - ograničava na razuman range
function testFuzz_example(uint256 amount) public {
    amount = bound(amount, 1, 100_000e18);
    staking.stake(amount);
}
```

### 2. **Provjeri Edge Cases Eksplicitno**

```solidity
// ✅ DOBRO - eksplicitno testira edge cases
function testFuzz_minimalAmounts_work(uint256 amount) public {
    amount = bound(amount, 1, 1); // Uvijek 1 wei
    // Test logika...
}
```

### 3. **Invarianti Trebaju Biti Jednostavni**

```solidity
// ✅ DOBRO - jednostavan i jasan invariant
function invariant_totalStaked_equals_sumOfBalances() public view {
    uint256 sum = 0;
    for (uint256 i = 0; i < users.length; i++) {
        sum += staking.balanceOf(users[i]);
    }
    assertEq(staking.totalStaked(), sum);
}

// ❌ LOŠE - previše kompleksan
function invariant_complexCalculation() public view {
    // 100 linija kompleksne logike...
}
```

### 4. **Dokumentiraj Invariante**

```solidity
/**
 * @notice Invariant: totalStaked() mora uvijek biti jednak sumi svih balanceOf(user)
 * @dev Ovo je fundamentalno svojstvo staking kontrakta. Ako ovo padne,
 *      znači da postoji bug u accounting logici.
 */
function invariant_totalStaked_equals_sumOfBalances() public view {
    // ...
}
```

### 5. **Koristi Descriptive Assert Messages**

```solidity
// ✅ DOBRO - jasna poruka
assertEq(staking.totalStaked(), sum, "Total staked must equal sum of balances");

// ❌ LOŠE - nejasna poruka
assertEq(staking.totalStaked(), sum);
```

### 6. **Testiraj S Različitim Vremenima**

```solidity
// ✅ DOBRO - testira s različitim vremenima
function testFuzz_rewards_increasesWithTime(uint256 timePassed) public {
    timePassed = bound(timePassed, 1 hours, 30 days);
    vm.warp(block.timestamp + timePassed);
    // Test logika...
}
```

---

## 🎓 Primjeri Korištenja

### Primjer 1: Fuzz Test za Stake

```solidity
function testFuzz_stake_updatesBalances(uint256 amount) public {
    // 1. Bound input na razuman range
    amount = bound(amount, 1, 100_000e18);
    
    // 2. Provjeri da user ima dovoljno tokena
    if (token.balanceOf(alice) < amount) {
        vm.prank(admin);
        token.mint(alice, amount);
    }
    
    // 3. Snimi stanje prije
    uint256 before = token.balanceOf(alice);
    uint256 stakedBefore = staking.balanceOf(alice);
    
    // 4. Izvedi operaciju
    vm.prank(alice);
    staking.stake(amount);
    
    // 5. Provjeri rezultat
    assertEq(token.balanceOf(alice), before - amount);
    assertEq(staking.balanceOf(alice), stakedBefore + amount);
}
```

### Primjer 2: Invariant Test

```solidity
function invariant_totalStaked_equals_sumOfBalances() public view {
    // 1. Izračunaj sumu svih user balances
    uint256 sum = 0;
    for (uint256 i = 0; i < users.length; i++) {
        sum += staking.balanceOf(users[i]);
    }
    
    // 2. Provjeri da je jednako total staked
    assertEq(staking.totalStaked(), sum, "Total staked must equal sum of balances");
}
```

---

## 🔗 Povezani Dokumenti

- [Foundry Fuzz Testing](https://book.getfoundry.sh/forge/fuzz-testing)
- [Foundry Invariant Testing](https://book.getfoundry.sh/forge/invariant-testing)
- [COMPLETE_DOCUMENTATION.md](./COMPLETE_DOCUMENTATION.md) - Opća dokumentacija kontrakata
- [TEST_FIXES_EXPLAINED.md](./TEST_FIXES_EXPLAINED.md) - Objašnjenje test fixova

---

## ✅ Sažetak

- **Fuzz testovi** automatski generiraju nasumične inpute i testiraju tisuće scenarija
- **Invariant testovi** provjeravaju da fundamentalna svojstva kontrakta uvijek vrijede
- Oba su kritična za sigurnost smart kontrakata
- **45 testova** pokrivaju sve kritične funkcije
- Svi testovi **prolaze** ✅

---

**Napomena:** Ovi testovi su dizajnirani da pronađu edge cases i osiguraju da kontrakti rade ispravno u svim scenarijima. Redovito pokrećite ove testove kada mijenjate kontrakte!

