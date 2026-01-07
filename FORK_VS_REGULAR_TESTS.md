# 🔬 Fork Testovi vs Regular Testovi - Detaljno Objašnjenje

## 📋 Što su Regular Testovi?

**Regular testovi** (unit testovi) rade na **lokalnom, praznom blockchainu** (Anvil):

```solidity
function setUp() public {
    // Kreira se NOVI, PRAZAN blockchain
    admin = makeAddr("admin");
    token = new JobsTokenFullV2(...); // Deploy na prazan chain
}
```

### Karakteristike:
- ✅ **Brzi** - nema mrežnih poziva
- ✅ **Izolirani** - svaki test ima čist state
- ✅ **Predvidljivi** - uvijek isti rezultati
- ❌ **Nerealni** - ne testiraju stvarni blockchain state
- ❌ **Ne testiraju integraciju** s postojećim kontraktima

---

## 🌐 Što su Fork Testovi?

**Fork testovi** rade na **kopiji stvarnog blockchaina** (Mainnet/Sepolia):

```solidity
function setUp() public {
    vm.createSelectFork(forkUrl); // Kopira STVARNI blockchain state
    // Sada imaš pristup svim postojećim kontraktima i transakcijama!
    token = new JobsTokenFullV2(...); // Deploy na forkovan chain
}
```

### Karakteristike:
- ✅ **Realni** - testiraju na stvarnom blockchain state-u
- ✅ **Integracija** - mogu koristiti postojeće kontrakte (Uniswap, WETH, itd.)
- ✅ **Realni gas costs** - vidiš stvarne gas troškove
- ✅ **Network effects** - testiraš kako tvoj kontrakt radi s drugim kontraktima
- ❌ **Sporiji** - zahtijeva RPC pozive
- ❌ **Ovisni o RPC** - ako RPC padne, testovi padnu

---

## 🔍 Detaljna Razlika

### 1. **Blockchain State**

**Regular Test:**
```solidity
// Prazan blockchain, samo tvoji kontrakti
block.number = 0
block.timestamp = 0
address(0x1).balance = 0 // Nema ETH
// Nema postojećih kontrakata
```

**Fork Test:**
```solidity
// Kopija stvarnog blockchaina
block.number = 18_000_000 // Stvarni block number
block.timestamp = 1_700_000_000 // Stvarni timestamp
address(0x1).balance = 1_000_000_000e18 // Stvarni ETH
// Imaš pristup svim postojećim kontraktima!
IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2); // WETH na Mainnet-u
```

### 2. **Gas Costs**

**Regular Test:**
```solidity
// Gas je "simuliran", možda nije 100% točan
staking.stake(1000e18); // gas: 100432
```

**Fork Test:**
```solidity
// Gas je STVARAN, točan kao na Mainnet-u
staking.stake(1000e18); // gas: 100432 (stvarni gas)
```

### 3. **Postojeći Kontrakti**

**Regular Test:**
```solidity
// Ne možeš koristiti postojeće kontrakte
// Moraš deployati sve sam
```

**Fork Test:**
```solidity
// Možeš koristiti postojeće kontrakte!
IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
uint256 balance = weth.balanceOf(someAddress); // Radi!
```

### 4. **Network Effects**

**Regular Test:**
```solidity
// Testiraš samo svoj kontrakt
// Ne vidiš kako radi s drugim kontraktima
```

**Fork Test:**
```solidity
// Testiraš kako tvoj kontrakt radi s drugim kontraktima
// Npr. možeš testirati integraciju s Uniswap, Aave, itd.
```

---

## 💪 Zašto su Fork Testovi "Jači"?

### 1. **Testiraju Real-World Scenarije**

**Regular test:**
```solidity
// Testiraš u "idealnim" uvjetima
// Ne vidiš kako radi u stvarnom svijetu
```

**Fork test:**
```solidity
// Testiraš na STVARNOM blockchainu
// Vidiš kako radi u stvarnom svijetu
// Npr. testiraš timestamp manipulation na stvarnom chainu
```

### 2. **Otkrivaju Skrivene Bugove**

**Primjer:**
```solidity
// Regular test možda neće otkriti:
// - Problem s gas optimizacijom
// - Problem s timestamp manipulation
// - Problem s reorg attack-om
// - Problem s integracijom s drugim kontraktima

// Fork test će otkriti:
// - Stvarni gas costs (možda previsoki)
// - Kako radi s stvarnim timestamp-om
// - Kako radi nakon reorg-a
// - Kako radi s drugim kontraktima
```

### 3. **Testiraju Security u Real-World Uvjetima**

**Tvoj Fork Test:**
```solidity
function testFork_timestampManipulation() public {
    // Testiraš timestamp manipulation na STVARNOM chainu
    // Vidiš kako miner može manipulirati timestamp
    // Provjeravaš da tvoj kontrakt još uvijek radi ispravno
}
```

**Regular test možda neće otkriti:**
- Problem s timestamp manipulation
- Problem s reorg attack-om
- Problem s gas griefing-om

---

## 📊 Kada Koristiti Koje?

### Regular Testovi - Koristi za:
- ✅ **Unit testovi** - testiranje pojedinačnih funkcija
- ✅ **Fuzz testovi** - testiranje s random inputima
- ✅ **Invariant testovi** - testiranje invarijanti
- ✅ **Brzi feedback** - kada želiš brzo vidjeti rezultate
- ✅ **CI/CD** - za brze testove u pipeline-u

### Fork Testovi - Koristi za:
- ✅ **Integration testovi** - testiranje integracije s drugim kontraktima
- ✅ **Security testovi** - testiranje napada (timestamp manipulation, reorg, itd.)
- ✅ **Gas optimization** - mjerenje stvarnih gas troškova
- ✅ **Pre-deployment** - testiranje prije deploymenta na Mainnet
- ✅ **Real-world scenariji** - testiranje kako radi u stvarnom svijetu

---

## 🎯 Tvoji Fork Testovi - Što Testiraju?

### 1. **Timestamp Manipulation**
```solidity
testFork_timestampManipulation()
```
**Zašto je važno:**
- Miner može manipulirati `block.timestamp` unutar ±15 sekundi
- Testiraš da tvoj kontrakt još uvijek radi ispravno
- **Regular test ne bi otkrio** ovaj problem jer ne testira na stvarnom chainu

### 2. **Reorg Simulation**
```solidity
testFork_reorgSimulation()
```
**Zašto je važno:**
- Blockchain se može reorganizirati
- Timestamp se može promijeniti
- Testiraš da rewards calculation još uvijek radi
- **Regular test ne bi otkrio** ovaj problem

### 3. **PeriodFinish Protection**
```solidity
testFork_periodFinishProtection()
```
**Zašto je važno:**
- Provjeravaš da rewards prestaju nakon `periodFinish`
- Čak i s timestamp manipulation
- **Regular test možda ne bi otkrio** edge case

---

## 🔬 Zaključak

**Fork testovi su "jači" jer:**
1. ✅ Testiraju na **stvarnom blockchainu**
2. ✅ Otkrivaju **skrivene bugove** (timestamp manipulation, reorg, itd.)
3. ✅ Testiraju **real-world scenarije**
4. ✅ Mjere **stvarne gas costs**
5. ✅ Testiraju **integraciju** s drugim kontraktima

**Ali:**
- ❌ Sporiji su od regular testova
- ❌ Ovisni su o RPC provideru
- ❌ Ne zamjenjuju regular testove - koristi **OBOJE**!

**Preporuka:**
- **80% regular testovi** - brzi, izolirani, za CI/CD
- **20% fork testovi** - za security, integration, real-world scenarije

---

## 📝 Tvoj Slučaj

**Imaš:**
- ✅ **87 regular testova** - unit, fuzz, invariant testovi
- ✅ **9 fork testova** - security, timestamp manipulation, reorg testovi

**To je odličan omjer!** Fork testovi testiraju security aspekte koje regular testovi ne mogu otkriti.
