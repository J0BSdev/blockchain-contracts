# 🔧 Debug Verifikacije - Bytecode Se Ne Podudara

## ❌ Problem

```
Fail - Unable to verify. Compiled contract deployment bytecode does NOT match the transaction deployment bytecode.
```

**Etherscan podržava `prague` verziju**, ali bytecode se i dalje ne podudara.

---

## 🔍 Mogući Uzroci

### 1. **Optimization Runs**
- Kontrakt možda nije deployan s `optimizer_runs = 200`
- Provjeri deployment script ili transakciju

### 2. **Solidity Verzija**
- Kontrakt možda nije deployan s `solc_version = "0.8.27"`
- Provjeri deployment script ili transakciju

### 3. **Constructor Args**
- Constructor args možda nisu ispravni
- Provjeri da su args točno kako su deployani

### 4. **Compiler Metadata**
- Compiler metadata se možda razlikuje
- Provjeri deployment bytecode metadata

---

## ✅ Rješenja

### Rješenje 1: Provjeri Deployment Script

Provjeri kako je kontrakt deployan u deployment scriptu:

```bash
cat src/tokens/script/deploy/DeployJobsTokenFullV2.s.sol
```

Provjeri:
- Koje su constructor args?
- Kako je pozvan `new JobsTokenFullV2(...)`?

---

### Rješenje 2: Provjeri Deployment Transakciju

**1. Dohvati transaction hash:**
```bash
# Pronađi transaction hash gdje je kontrakt deployan
# Možeš koristiti Etherscan ili blockchain explorer
```

**2. Provjeri transaction details:**
```bash
cast tx <TX_HASH> --rpc-url $RPC_URL
```

**3. Provjeri compiler metadata:**
```bash
cast code $TOKEN_ADDRESS --rpc-url $RPC_URL | tail -c 100
```

---

### Rješenje 3: Provjeri Optimization Runs

Možda je kontrakt deployan s drugim optimization runs:

**Pokušaj s različitim optimization runs:**

```bash
# S 1000 runs
forge verify-contract \
  --num-of-optimizations 1000 \
  ...

# S 200 runs (trenutno)
forge verify-contract \
  --num-of-optimizations 200 \
  ...
```

---

### Rješenje 4: Provjeri Solidity Verziju

Možda je kontrakt deployan s drugom Solidity verzijom:

**Provjeri deployment script:**
```bash
grep -E "pragma|solc" src/tokens/script/deploy/DeployJobsTokenFullV2.s.sol
```

**Provjeri foundry.toml:**
```bash
grep solc_version foundry.toml
```

---

### Rješenje 5: Manual Verification na Etherscan-u

Ako automatska verifikacija ne uspije, koristi manual verification:

1. **Idi na Etherscan:**
   ```
   https://sepolia.etherscan.io/address/$TOKEN_ADDRESS#code
   ```

2. **Klikni "Verify and Publish"**

3. **Odaberi "Via Standard JSON Input"**

4. **Upload:**
   - Standard JSON Input (iz `out/JobsTokenFullV2.sol/JobsTokenFullV2.json`)
   - Constructor Arguments
   - Compiler Settings (EVM Version, Optimization, Solidity Version)

5. **Etherscan će automatski pronaći ispravne settings**

---

## 🔍 Detaljna Provjera

### Provjeri Deployment Bytecode

```bash
# Dohvati deployed bytecode
cast code $TOKEN_ADDRESS --rpc-url $RPC_URL > deployed_bytecode.txt

# Dohvati local bytecode
forge build
cat out/JobsTokenFullV2.sol/JobsTokenFullV2.json | jq -r '.deployedBytecode.object' > local_bytecode.txt

# Usporedi
diff deployed_bytecode.txt local_bytecode.txt
```

### Provjeri Compiler Metadata

```bash
# Dohvati compiler metadata iz deployed bytecode
cast code $TOKEN_ADDRESS --rpc-url $RPC_URL | tail -c 100

# Provjeri local compiler metadata
cat out/JobsTokenFullV2.sol/JobsTokenFullV2.json | jq -r '.deployedBytecode.object' | tail -c 100
```

---

## 📋 Checklist za Verifikaciju

- [ ] EVM verzija: `prague` ✅
- [ ] Optimization runs: `200` (provjeri da se podudara)
- [ ] Solidity verzija: `0.8.27` (provjeri da se podudara)
- [ ] Constructor args: Ispravni (provjeri deployment script)
- [ ] Compiler metadata: Podudara se (provjeri bytecode)

---

## 🎯 Preporuka

### Najbolje Rješenje: Manual Verification

**Manual verification na Etherscan-u je najbolja opcija** jer:
- ✅ Etherscan automatski pronalazi ispravne compiler settings
- ✅ Ne moraš ručno provjeravati sve settings
- ✅ Brže i pouzdanije

**Koraci:**
1. Idi na Etherscan kontrakt stranicu
2. Klikni "Verify and Publish"
3. Odaberi "Via Standard JSON Input"
4. Upload Standard JSON Input iz `out/JobsTokenFullV2.sol/JobsTokenFullV2.json`
5. Etherscan će automatski pronaći ispravne settings

---

## 📚 Korisni Linkovi

- **Etherscan Verification:** https://sepolia.etherscan.io/verifyContract
- **Foundry Verify:** https://book.getfoundry.sh/reference/forge/forge-verify-contract
- **Compiler Metadata:** https://docs.soliditylang.org/en/latest/metadata.html

---

## ✅ Sljedeći Koraci

1. ✅ Vratio sam `prague` verziju u `foundry.toml`
2. ⬜ Provjeri deployment script - kako je kontrakt deployan?
3. ⬜ Provjeri deployment transakciju - koje su compiler settings?
4. ⬜ Pokušaj manual verification na Etherscan-u (najbolja opcija)

