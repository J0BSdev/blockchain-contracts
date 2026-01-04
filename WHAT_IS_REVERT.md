# 🔄 Što Znači "Revert" u Solidity-u?

## 📚 Osnovno Objašnjenje

**Revert** = **Poništavanje transakcije** - kontrakt odbija izvršiti operaciju i vraća sve promjene.

---

## 🎯 Što Se Događa Kada Kontrakt Reverta?

### 1. **Transakcija se poništava**
- Sve promjene stanja se **vraćaju** (kao da se ništa nije dogodilo)
- Gas se **troši** (ali transakcija se ne izvršava)
- Blockchain se vraća na **prethodno stanje**

### 2. **Poruka o grešci**
- Kontrakt vraća **error message** (ako je specificiran)
- Npr: `"Insufficient balance"`, `"Access denied"`, itd.

### 3. **Gas se troši**
- Gas se **troši** iako transakcija ne uspije
- To je **zaštita** protiv spam napada

---

## 💻 Primjeri u Tvojim Kontraktima

### Primjer 1: Stake sa Zero Amount

```solidity
function stake(uint256 amount) external {
    if (amount == 0) revert ZeroAmount(); // ← REVERT!
    // ...
}
```

**Što se događa:**
- Korisnik pozove `staking.stake(0)`
- Kontrakt provjerava: `amount == 0` → **TRUE**
- Kontrakt poziva `revert ZeroAmount()`
- Transakcija se **poništava**
- Korisnik dobiva error: `"ZeroAmount"`
- Gas se troši, ali ništa se ne mijenja

---

### Primjer 2: Mint bez MINTER_ROLE

```solidity
function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
    // ...
}
```

**Što se događa:**
- Korisnik bez `MINTER_ROLE` pozove `token.mint(...)`
- `onlyRole(MINTER_ROLE)` provjerava: korisnik nema role
- Kontrakt poziva `revert AccessControlUnauthorizedAccount(...)`
- Transakcija se **poništava**
- Korisnik dobiva error: `"AccessControlUnauthorizedAccount"`
- Gas se troši, ali ništa se ne mijenja

---

### Primjer 3: Stake bez Dovoljno Tokena

```solidity
function stake(uint256 amount) external {
    stakingToken.safeTransferFrom(msg.sender, address(this), amount);
    // ...
}
```

**Što se događa:**
- Korisnik pozove `staking.stake(1000)` ali ima samo `500` tokena
- `safeTransferFrom` provjerava: korisnik nema dovoljno tokena
- ERC20 kontrakt poziva `revert ERC20InsufficientBalance(...)`
- Transakcija se **poništava**
- Korisnik dobiva error: `"ERC20InsufficientBalance"`
- Gas se troši, ali ništa se ne mijenja

---

## 🔍 Razlike: Revert vs Return vs Throw

| Akcija | Što Se Događa | Gas | Stanje |
|--------|---------------|-----|--------|
| **Revert** | Poništava transakciju | Troši se | Vraća se na prethodno |
| **Return** | Vraća vrijednost | Troši se | Promjene se zadržavaju |
| **Throw** (staro) | Poništava transakciju | Troši SVE gas | Vraća se na prethodno |

**Napomena:** `throw` je **deprecated** - koristi se `revert` umjesto njega.

---

## 🛡️ Zašto Revert Postoji?

### 1. **Sigurnost**
- Sprječava neispravne operacije
- Zaštita od grešaka i napada

### 2. **Validacija**
- Provjerava ulazne podatke
- Npr: provjera da amount nije 0, da korisnik ima dovoljno tokena, itd.

### 3. **Atomicity**
- Transakcija se izvršava **u cijelosti ili uopće ne**
- Nema "djelomičnih" transakcija

---

## 📊 Revert u Testovima

### Zašto Testovi Testiraju Revert?

**Testovi eksplicitno testiraju revert scenarije** da provjere da kontrakt ispravno validira:

```solidity
function test_stake_revertOnZero() public {
    vm.expectRevert(); // Očekujemo revert!
    staking.stake(0);  // Poziv koji bi trebao revertati
}
```

**Što test provjerava:**
- ✅ Da kontrakt **reverta** kada se pozove sa zero amount
- ✅ Da kontrakt **ne dozvoljava** neispravne operacije
- ✅ Da kontrakt **ispravno validira** ulazne podatke

---

## 🎯 Različiti Načini Reverta

### 1. **Revert sa Custom Error**

```solidity
error ZeroAmount();

function stake(uint256 amount) external {
    if (amount == 0) revert ZeroAmount(); // ← Custom error
}
```

**Prednosti:**
- ✅ Jeftiniji (manje gasa)
- ✅ Type-safe
- ✅ Lako parsiranje

---

### 2. **Revert sa String Porukom**

```solidity
function stake(uint256 amount) external {
    require(amount > 0, "Amount must be greater than zero"); // ← String error
}
```

**Prednosti:**
- ✅ Ljudski čitljive poruke
- ❌ Skupije (više gasa)

---

### 3. **Revert sa Modifierom**

```solidity
modifier onlyRole(bytes32 role) {
    if (!hasRole(role, msg.sender)) {
        revert AccessControlUnauthorizedAccount(msg.sender, role);
    }
    _;
}

function mint(...) external onlyRole(MINTER_ROLE) {
    // ...
}
```

**Prednosti:**
- ✅ Reusable
- ✅ Čist kod

---

## 💡 Primjeri Iz Tvojih Kontrakata

### JobsTokenStaking

```solidity
// Revert ako je amount 0
if (amount == 0) revert ZeroAmount();

// Revert ako nema dovoljno rewards
if (amount > _availableRewards()) revert InsufficientRewardPool();

// Revert ako nema role
function notifyRewardAmount(...) external onlyRole(MANAGER_ROLE) {
    // ...
}
```

### JobsTokenVestingERC20

```solidity
// Revert ako je vesting revoked
require(!v.revoked, "Revoked");

// Revert ako nema ništa za claimati
if (claimable == 0) revert NothingToClaim();
```

---

## 🔄 Revert vs Success

### Success (Uspješna Transakcija)

```
Korisnik → stake(100) → ✅ Uspjeh
- Tokeni se prebacuju u staking kontrakt
- Balance se ažurira
- Event se emitira
- Gas se troši
```

### Revert (Neuspješna Transakcija)

```
Korisnik → stake(0) → ❌ Revert
- Transakcija se poništava
- Ništa se ne mijenja
- Error se vraća
- Gas se troši (ali ništa se ne događa)
```

---

## 📈 Statistika Reverta u Testovima

### Zašto Toliko Reverta?

**91% reverta u invariant testovima je NORMALNO** jer:

1. **Random pozivi** - Testovi pozivaju sve funkcije s random parametrima
2. **Validacija** - Mnogi pozivi će revertati zbog validacije (nema role, nema tokena, itd.)
3. **Sigurnost** - To pokazuje da kontrakt ispravno validira ulazne podatke

**Primjer:**
```
| JobsTokenFullV2  | mint               | 5318  | 5317    | 0        |
```

**Objašnjenje:**
- 5318 poziva `mint()` funkcije
- 5317 reverta (99.98%)
- Zašto? Random pozivi bez `MINTER_ROLE` → revert!

---

## ✅ Zaključak

**Revert = Zaštita**

- ✅ Sprječava neispravne operacije
- ✅ Validira ulazne podatke
- ✅ Osigurava sigurnost kontrakta
- ✅ Atomicity (sve ili ništa)

**Revert u testovima = Dobro**

- ✅ Pokazuje da kontrakt ispravno validira
- ✅ Pokazuje da kontrakt je siguran
- ✅ Pokazuje da edge cases su pokriveni

---

## 🔗 Korisni Linkovi

- **Solidity Revert:** https://docs.soliditylang.org/en/latest/control-structures.html#revert
- **Custom Errors:** https://docs.soliditylang.org/en/latest/contracts.html#errors
- **Require vs Revert:** https://docs.soliditylang.org/en/latest/control-structures.html#error-handling-assert-require-revert-and-exceptions

