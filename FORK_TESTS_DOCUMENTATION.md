 # 🌐 Fork Testovi - Kompletna Dokumentacija

## 📋 Sadržaj

1. [Što su Fork Testovi?](#što-su-fork-testovi)
2. [Zašto ih Koristiti?](#zašto-ih-koristiti)
3. [Kako ih Pokrenuti?](#kako-ih-pokrenuti)
4. [Što Testiraju?](#što-testiraju)
5. [Struktura Testova](#struktura-testova)
6. [Best Practices](#best-practices)
7. [Troubleshooting](#troubleshooting)

---

## 🎯 Što su Fork Testovi?

**Fork testovi** su testovi koji rade na **kopiji stvarnog blockchaina** (Mainnet/Sepolia/Arbitrum, itd.). Umjesto da kreiraju novi, prazan blockchain, oni **fork-aju** (kopiraju) postojeći blockchain state i testiraju tvoje kontrakte na njemu.

### Ključna Razlika:

**Regular Test:**
```solidity
function setUp() public {
    // Prazan blockchain, block.number = 0
    token = new JobsTokenFullV2(...);
}
```

**Fork Test:**
```solidity
function setUp() public {
    vm.createSelectFork(forkUrl); // Kopira STVARNI blockchain
    // block.number = 18_000_000 (stvarni block)
    token = new JobsTokenFullV2(...);
}
```

---

## 💪 Zašto ih Koristiti?

### 1. **Real-World Testiranje**
- Testiraš na **stvarnom blockchain state-u**
- Vidiš kako kontrakt radi u **stvarnim uvjetima**
- Otkrivaš bugove koje regular testovi ne bi otkrili

### 2. **Security Testiranje**
- Testiraš **timestamp manipulation** napade
- Testiraš **reorg (reorganizaciju)** scenarije
- Provjeravaš **edge case-ove** u real-world uvjetima

### 3. **Gas Optimization**
- Mjeriš **stvarne gas costs**
- Optimiziraš prije deploymenta na Mainnet

### 4. **Integration Testiranje**
- Testiraš integraciju s **postojećim kontraktima** (Uniswap, WETH, itd.)
- Provjeravaš **network effects**

---

## 🚀 Kako ih Pokrenuti?

### Opcija 1: Korištenje Skripte (Preporučeno)

```bash
# Postavi RPC URL u .env
export FORK_URL=https://sepolia.infura.io/v3/YOUR_KEY
# ili
export FORK_URL=$RPC_URL

# Pokreni fork testove
./run_fork_test.sh
```

### Opcija 2: Direktno s Forge

```bash
# S env varijablom
forge test --match-contract Fork --fork-url $FORK_URL -vv

# Ili direktno
forge test --match-contract Fork --fork-url https://sepolia.infura.io/v3/YOUR_KEY -vv
```

### Opcija 3: Korištenje Anvil (Lokalni Fork)

```bash
# Terminal 1: Pokreni Anvil s fork-om
anvil --fork-url https://sepolia.infura.io/v3/YOUR_KEY

# Terminal 2: Pokreni testove
forge test --match-contract Fork --fork-url http://localhost:8545 -vv
```

### Opcija 4: Bez RPC URL-a (Test će biti preskočen)

```bash
# Ako nema FORK_URL ili RPC_URL, test će automatski biti preskočen
forge test --match-contract Fork -vv
```

---

## 🧪 Što Testiraju?

### 1. **Basic Deployment** (`testFork_basicDeployment`)
```solidity
/**
 * Testira da se kontrakti ispravno deployaju na forkovanom blockchainu
 * Provjerava: name, symbol, cap, totalSupply
 */
```

**Zašto je važno:**
- Provjerava da deployment radi na stvarnom chainu
- Otkriva probleme s constructor argumentima

---

### 2. **Staking Functionality** (`testFork_stakingWorks`)
```solidity
/**
 * Testira da staking funkcionalnost radi na forkovanom blockchainu
 * Provjerava: approve, stake, balance updates
 */
```

**Zašto je važno:**
- Provjerava da staking radi u real-world uvjetima
- Otkriva probleme s gas costs

---

### 3. **Rewards Distribution** (`testFork_rewardsWork`)
```solidity
/**
 * Testira da reward distribucija radi ispravno
 * Provjerava: notifyRewardAmount, pendingRewards, claim
 */
```

**Zašto je važno:**
- Provjerava da rewards calculation radi ispravno
- Otkriva probleme s time-based logikom

---

### 4. **Timestamp Manipulation** (`testFork_timestampManipulation`)
```solidity
/**
 * Testira timestamp manipulation napad scenarij
 * Miner može manipulirati block.timestamp unutar ±15 sekundi
 * Provjerava da kontrakt još uvijek radi ispravno
 */
```

**Zašto je važno:**
- **Regular test ne bi otkrio** ovaj problem
- Miner može manipulirati timestamp
- Testiraš da rewards calculation još uvijek radi

**Što testira:**
1. Timestamp manipulation (+15 sekundi)
2. Rewards calculation nakon manipulation
3. PeriodFinish zaštita

---

### 5. **Reorg Simulation** (`testFork_reorgSimulation`)
```solidity
/**
 * Testira blockchain reorganizaciju (reorg) scenarij
 * Blockchain se može reorganizirati, timestamp se mijenja
 * Provjerava da rewards calculation još uvijek radi
 */
```

**Zašto je važno:**
- **Regular test ne bi otkrio** ovaj problem
- Blockchain se može reorganizirati
- Timestamp se može promijeniti unazad

**Što testira:**
1. Normal rewards accrual
2. Reorg (timestamp se vraća unazad)
3. Rewards calculation nakon reorg-a

---

### 6. **Vesting Timestamp Manipulation** (`testFork_vestingTimestampManipulation`)
```solidity
/**
 * Testira vesting kontrakt s timestamp manipulation
 * Provjerava da vesting calculations su resilient na timestamp manipulation
 */
```

**Zašto je važno:**
- Vesting ovisi o `block.timestamp`
- Testiraš da vesting još uvijek radi ispravno
- ±15 sekundi je zanemarivo u 30 dana vesting periodu

---

### 7. **PeriodFinish Protection** (`testFork_periodFinishProtection`)
```solidity
/**
 * Testira da periodFinish ograničava rewards čak i s timestamp manipulation
 * Provjerava da rewards prestaju nakon periodFinish
 */
```

**Zašto je važno:**
- Provjeravaš da rewards **prestaju** nakon `periodFinish`
- Čak i s timestamp manipulation
- **Regular test možda ne bi otkrio** edge case

---

### 8. **Multiple Users** (`testFork_multipleUsersTimestampManipulation`)
```solidity
/**
 * Testira multiple users staking s timestamp manipulation
 * Provjerava da rewards su distribuirane ispravno
 */
```

**Zašto je važno:**
- Testiraš da rewards su distribuirane **proporcionalno** stake-u
- Veći staker dobiva više rewards
- Čak i s timestamp manipulation

---

### 9. **Timestamp Bounds** (`testFork_timestampWithinBounds`)
```solidity
/**
 * Testira da kontrakt radi čak i ako se timestamp mijenja unutar granica
 * Testira različite timestamp vrijednosti unutar miner manipulation limits
 */
```

**Zašto je važno:**
- Testiraš **različite** timestamp vrijednosti
- Unutar miner manipulation limits (±15 sekundi)
- Provjeravaš da kontrakt **uvijek** radi ispravno

---

## 📁 Struktura Testova

### File: `test/Fork.t.sol`

```solidity
contract ForkTest is Test {
    // Constants
    uint256 internal constant CAP = 1_000_000_000e18;
    uint256 internal constant INITIAL_MINT = 100_000_000e18;
    uint256 internal constant REWARD_AMOUNT = 10_000_000e18;
    uint256 internal constant REWARDS_DURATION = 7 days;

    // Contracts
    JobsTokenFullV2 internal token;
    JobsTokenStaking internal staking;
    JobsTokenVesting internal vesting;

    // Addresses
    address internal admin;
    address internal alice;
    address internal bob;

    function setUp() public {
        // Fork blockchain
        vm.createSelectFork(forkUrl);
        
        // Deploy contracts
        // Setup roles
        // Mint tokens
    }

    // Basic Tests
    function testFork_basicDeployment() public view { ... }
    function testFork_stakingWorks() public { ... }
    function testFork_rewardsWork() public { ... }

    // Security Tests
    function testFork_timestampManipulation() public { ... }
    function testFork_reorgSimulation() public { ... }
    function testFork_vestingTimestampManipulation() public { ... }
    function testFork_periodFinishProtection() public { ... }
    function testFork_multipleUsersTimestampManipulation() public { ... }
    function testFork_timestampWithinBounds() public { ... }
}
```

---

## 🎯 Best Practices

### 1. **Koristi Env Varijable**
```bash
# U .env
FORK_URL=https://sepolia.infura.io/v3/YOUR_KEY
RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY
```

### 2. **Koristi Skriptu za Pokretanje**
```bash
# Umjesto direktnog forge test poziva
./run_fork_test.sh
```

### 3. **Testiraj na Testnet Prvo**
```solidity
// Koristi Sepolia za development
string memory forkUrl = vm.envOr("FORK_URL", string("https://rpc.sepolia.org"));

// Mainnet samo za final testing
// string memory forkUrl = vm.envOr("MAINNET_RPC_URL", string(""));
```

### 4. **Skip Testove Ako Nema RPC**
```solidity
if (bytes(forkUrl).length == 0) {
    vm.skip(true); // Preskoči test ako nema RPC URL
    return;
}
```

### 5. **Koristi Verbose Output**
```bash
# Za debugging
forge test --match-contract Fork --fork-url $FORK_URL -vvv

# Za normal output
forge test --match-contract Fork --fork-url $FORK_URL -vv
```

### 6. **Testiraj Različite Scenarije**
- ✅ Timestamp manipulation
- ✅ Reorg simulation
- ✅ Multiple users
- ✅ Edge cases

---

## 🔧 Troubleshooting

### Problem: "could not instantiate forked environment"

**Razlog:** RPC URL nije dostupan ili je neispravan.

**Rješenje:**
```bash
# Provjeri RPC URL
echo $FORK_URL

# Testiraj RPC URL
curl -X POST -H "Content-Type: application/json" \
  --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  $FORK_URL

# Koristi alternativni RPC provider
export FORK_URL=https://eth.llamarpc.com
```

---

### Problem: "AccessControlUnauthorizedAccount"

**Razlog:** Admin nema potrebne role prije poziva funkcija.

**Rješenje:**
```solidity
// PRIJE (pogrešno):
token.mint(admin, amount); // ❌ Admin nema MINTER_ROLE

// NAKON (ispravno):
token.grantRole(token.MINTER_ROLE(), admin); // ✅ Prvo grantaj
token.mint(admin, amount); // ✅ Sada može mintati
```

---

### Problem: Testovi su Spori

**Razlog:** Fork testovi zahtijevaju RPC pozive.

**Rješenje:**
```bash
# Koristi lokalni Anvil fork
anvil --fork-url $FORK_URL

# U drugom terminalu
forge test --match-contract Fork --fork-url http://localhost:8545 -vv
```

---

### Problem: "Test Skipped"

**Razlog:** Nema `FORK_URL` ili `RPC_URL` env varijable.

**Rješenje:**
```bash
# Postavi env varijablu
export FORK_URL=https://sepolia.infura.io/v3/YOUR_KEY

# Ili u .env
echo "FORK_URL=https://sepolia.infura.io/v3/YOUR_KEY" >> .env
```

---

## 📊 Rezultati Testova

### Očekivani Output:

```
Ran 9 tests for test/Fork.t.sol:ForkTest
[PASS] testFork_basicDeployment() (gas: 20815)
[PASS] testFork_stakingWorks() (gas: 117015)
[PASS] testFork_rewardsWork() (gas: 264974)
[PASS] testFork_timestampManipulation() (gas: 219843)
[PASS] testFork_reorgSimulation() (gas: 215318)
[PASS] testFork_vestingTimestampManipulation() (gas: 156644)
[PASS] testFork_periodFinishProtection() (gas: 212748)
[PASS] testFork_multipleUsersTimestampManipulation() (gas: 259324)
[PASS] testFork_timestampWithinBounds() (gas: 242534)

Suite result: ok. 9 passed; 0 failed; 0 skipped
```

---

## 🔗 Povezani Dokumenti

- [FORK_VS_REGULAR_TESTS.md](./FORK_VS_REGULAR_TESTS.md) - Razlika između fork i regular testova
- [FORK_ATTACK_EXPLANATION.md](./FORK_ATTACK_EXPLANATION.md) - Objašnjenje fork-based napada
- [run_fork_test.sh](./run_fork_test.sh) - Skripta za pokretanje fork testova

---

## 📝 Napomene

1. **Fork testovi su sporiji** od regular testova - to je normalno
2. **Koristi testnet** za development, mainnet samo za final testing
3. **Ne zamjenjuju regular testove** - koristi OBOJE!
4. **RPC provider može imati rate limits** - koristi lokalni Anvil ako je moguće

---

## ✅ Checklist Prije Deploymenta

- [ ] Svi fork testovi prolaze
- [ ] Testirao si na testnet fork-u
- [ ] Provjerio si gas costs
- [ ] Testirao si security scenarije (timestamp manipulation, reorg)
- [ ] Testirao si multiple users scenarije
- [ ] Provjerio si edge cases

---

**Napravljeno:** 2026-01-06  
**Zadnje ažurirano:** 2026-01-06

