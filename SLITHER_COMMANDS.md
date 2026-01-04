# 🔒 Slither - Različite Komande

## 📋 Osnovne Komande

### 1. **Analiziraj cijeli projekt**
```bash
export PATH=$PATH:$HOME/.local/bin
slither .
```

### 2. **Analiziraj specifičan kontrakt**
```bash
export PATH=$PATH:$HOME/.local/bin
slither src/tokens/staking/JobsTokenStaking.sol
```

### 3. **Sa human-readable summary**
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --print human-summary
```

### 4. **Isključi dependencies (samo tvoji kontrakti)**
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --exclude-dependencies
```

### 5. **Isključi optimization issues**
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --exclude-optimization
```

### 6. **Kombinacija (preporučeno)**
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --exclude-dependencies --exclude-optimization --print human-summary
```

---

## 📊 Različiti Output Formati

### 1. **JSON output (za parsiranje)**
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --exclude-dependencies --exclude-optimization --json slither-report.json
```

### 2. **Markdown output**
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --exclude-dependencies --exclude-optimization --markdown slither-report.md
```

### 3. **CSV output**
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --exclude-dependencies --exclude-optimization --csv slither-report.csv
```

### 4. **TXT output**
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --exclude-dependencies --exclude-optimization --print human-summary > slither-report.txt
```

---

## 🎯 Filtriranje Issues

### 1. **Samo HIGH i MEDIUM issues**
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --exclude-dependencies --exclude-optimization --filter-paths "HIGH|MEDIUM"
```

### 2. **Samo HIGH issues**
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --exclude-dependencies --exclude-optimization --filter-paths "HIGH"
```

### 3. **Isključi određene detektore**
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --exclude-dependencies --exclude-optimization --exclude-informational
```

### 4. **Samo određeni detektor (npr. reentrancy)**
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --exclude-dependencies --exclude-optimization --detect reentrancy-eth,reentrancy-no-eth
```

---

## 🔍 Detaljne Analize

### 1. **Verbose mode (više detalja)**
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --exclude-dependencies --exclude-optimization -vvv
```

### 2. **Samo tvoji kontrakti (bez OpenZeppelin)**
```bash
export PATH=$PATH:$HOME/.local/bin
slither src/ --exclude-dependencies --exclude-optimization
```

### 3. **Analiziraj samo staking kontrakt**
```bash
export PATH=$PATH:$HOME/.local/bin
slither src/tokens/staking/JobsTokenStaking.sol --exclude-dependencies --exclude-optimization --print human-summary
```

### 4. **Analiziraj samo vesting kontrakt**
```bash
export PATH=$PATH:$HOME/.local/bin
slither src/tokens/vesting/JobsTokenVestingERC20.sol --exclude-dependencies --exclude-optimization --print human-summary
```

### 5. **Analiziraj samo token kontrakt**
```bash
export PATH=$PATH:$HOME/.local/bin
slither src/tokens/erc20/JobsTokenFullV2.sol --exclude-dependencies --exclude-optimization --print human-summary
```

---

## 🛠️ Napredne Opcije

### 1. **Sa custom config file**
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --config slither.config.json
```

### 2. **Sa custom compiler**
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --solc-version 0.8.27
```

### 3. **Sa custom solc path**
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --solc-path /usr/bin/solc
```

### 4. **Sa custom remappings**
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --solc-remaps "@openzeppelin/=lib/openzeppelin-contracts/"
```

---

## 📝 Korisne Kombinacije

### 1. **Brza provjera (samo HIGH/MEDIUM)**
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --exclude-dependencies --exclude-optimization --exclude-informational --print human-summary
```

### 2. **Detaljna analiza za report**
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --exclude-dependencies --exclude-optimization --json slither-report.json --print human-summary
```

### 3. **Samo kritični kontrakti**
```bash
export PATH=$PATH:$HOME/.local/bin
slither src/tokens/staking/JobsTokenStaking.sol src/tokens/vesting/JobsTokenVestingERC20.sol src/tokens/erc20/JobsTokenFullV2.sol --exclude-dependencies --exclude-optimization --print human-summary
```

### 4. **Samo reentrancy i access-control issues**
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --exclude-dependencies --exclude-optimization --detect reentrancy-eth,reentrancy-no-eth,access-control --print human-summary
```

---

## 🚀 Helper Script (već postoji)

```bash
# Koristi postojeći script
./run_slither.sh all
./run_slither.sh staking
./run_slither.sh vesting
./run_slither.sh token
```

---

## 💡 Preporuke

### Za brzu provjeru:
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --exclude-dependencies --exclude-optimization --exclude-informational --print human-summary
```

### Za detaljnu analizu:
```bash
export PATH=$PATH:$HOME/.local/bin
slither . --exclude-dependencies --exclude-optimization --json slither-report.json --print human-summary
```

### Za specifičan kontrakt:
```bash
export PATH=$PATH:$HOME/.local/bin
slither src/tokens/staking/JobsTokenStaking.sol --exclude-dependencies --exclude-optimization --print human-summary
```

---

## 📚 Dodatne Informacije

- **Slither dokumentacija:** https://github.com/crytic/slither/wiki
- **Detector lista:** https://github.com/crytic/slither/wiki/Detector-Documentation
- **Command line opcije:** `slither --help`

