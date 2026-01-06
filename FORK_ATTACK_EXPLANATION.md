# 🔴 FORK-BASED ATTACK - Objašnjenje

## Što je Fork-Based Attack?

Fork-based attack je napad gdje napadač koristi **blockchain fork** (reorganizaciju ili hard fork) da izvrši napad na smart contract.

## Tipovi Fork-Based Napada:

### 1. **Replay Attack** (Cross-Chain)
- **Problem**: Transakcija se izvršava na jednom chainu, a zatim se **ponavlja** na drugom
- **Primjer**: Signature se koristi na Mainnet-u i ponovno na Arbitrum-u
- **Zaštita**: Koristi `chainId` u signature (ERC20Permit to radi ✅)

### 2. **Reorg Attack** (Blockchain Reorganizacija)
- **Problem**: Blockchain se reorganizira, mijenja se `block.timestamp` ili `block.number`
- **Primjer**: 
  - Blok 100 ima `timestamp = 1000`
  - Reorg: blok 100 sada ima `timestamp = 999`
  - Kontrakt koji ovisi o točnom vremenu može biti ranjiv
- **Zaštita**: Koristi `block.number` umjesto `block.timestamp` za kritične provjere

### 3. **Timestamp Manipulation**
- **Problem**: Miner/validator može manipulirati `block.timestamp` (unutar granica)
- **Primjer**: Miner postavlja `block.timestamp` malo unaprijed/unazad
- **Zaštita**: Ne oslanjaj se na precizno vrijeme, koristi `block.number` za periodične provjere

## Tvoji Kontrakti - Analiza:

### ✅ **JobsTokenFullV2** - SIGURAN
- Koristi `ERC20Permit` koji uključuje `chainId` u signature
- Nema ovisnosti o `block.timestamp` za kritične provjere
- **Status**: Zaštićen od replay napada

### ⚠️ **JobsTokenStaking** - POTENCIJALNO RANJIV
- Koristi `block.timestamp` za:
  - `lastUpdateTime` (linija 173, 436)
  - `periodFinish` (linija 437)
  - Reward calculation (linija 198, 414-416)
- **Rizik**: Reorg može promijeniti `block.timestamp` i utjecati na reward calculation
- **Zaštita**: 
  - ✅ Koristi `periodFinish` kao granicu (ne ovisi o preciznom vremenu)
  - ✅ `_lastTimeRewardApplicable()` ograničava na `periodFinish`
  - ⚠️ Mala ranjivost: miner može manipulirati timestamp unutar granica (±15 sekundi)

### ⚠️ **JobsTokenVesting** - POTENCIJALNO RANJIV
- Koristi `block.timestamp` za:
  - `releasable()` calculation (linija 128, 130)
  - Vesting schedule (linija 110)
- **Rizik**: Reorg može promijeniti `block.timestamp` i utjecati na vesting calculation
- **Zaštita**:
  - ✅ Vesting je linearno, ne ovisi o preciznom vremenu
  - ⚠️ Mala ranjivost: miner može manipulirati timestamp unutar granica

## Preporuke:

### 1. **Za Staking**:
```solidity
// Umjesto:
if (block.timestamp < periodFinish)

// Možeš koristiti:
if (block.number < periodFinishBlock)
```

### 2. **Za Vesting**:
- Trenutna implementacija je **prihvatljiva** jer:
  - Vesting je linearno (ne ovisi o preciznom vremenu)
  - Miner može manipulirati timestamp samo unutar granica (±15 sekundi)
  - To ne može značajno utjecati na vesting calculation

### 3. **Općenito**:
- ✅ Koristi `block.number` za periodične provjere (npr. "nakon 1000 blokova")
- ✅ Koristi `block.timestamp` za user-friendly features (vesting, rewards)
- ⚠️ Ne oslanjaj se na precizno vrijeme za kritične provjere

## Zaključak:

Tvoji kontrakti su **relativno sigurni** od fork-based napada:
- ✅ Replay napadi: Zaštićeni (ERC20Permit)
- ⚠️ Reorg napadi: Mala ranjivost (timestamp manipulation unutar granica)
- ✅ Kritične provjere: Koriste granice (`periodFinish`), ne precizno vrijeme

**Preporuka**: Trenutna implementacija je **prihvatljiva za produkciju**. Timestamp manipulation unutar granica (±15 sekundi) ne može značajno utjecati na funkcionalnost.
