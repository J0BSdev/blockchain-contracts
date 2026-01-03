# 🎯 Akcijski Plan - Što Dalje?

## 📊 Trenutno Stanje

✅ **Gotovo:**
- ✅ 7 kontrakata (ERC20, Staking, Vesting)
- ✅ **87 testova** (42 osnovnih + 45 fuzz/invariant) - **SVI PROLAZE** ✅
- ✅ Kompletna dokumentacija (7 MD fajlova)
- ✅ Deploy skripte spremne
- ✅ NatSpec dokumentacija u svim kontraktima

---

## 🚀 Konkretni Sljedeći Koraci (Prioritetno)

### 🔥 **PRIORITET 1: Verifikacija Kontrakata** (1-2 sata)

**Zašto:** Da bi kontrakti bili transparentni i lako provjerljivi na block exploreru.

**Što napraviti:**

#### 1. Pripremi Environment Varijable

```bash
# Dodaj u ~/.bashrc ili ~/.zshrc
export ETHERSCAN_API_KEY="tvoj_etherscan_api_key"
export SEPOLIA_RPC="https://sepolia.infura.io/v3/tvoj_key"
export PRIVATE_KEY="tvoj_private_key_hex"
export TOKEN_ADDRESS="0x..." # Adresa deployanog tokena
export STAKING_ADDRESS="0x..." # Adresa deployanog staking kontrakta
export VESTING_ADDRESS="0x..." # Adresa deployanog vesting kontrakta
export ADMIN_ADDRESS="0x..." # Tvoja admin adresa
```

#### 2. Verificiraj JobsTokenFullV2

```bash
# Prvo provjeri constructor parametre
cast abi-encode "constructor(string,string,uint256,address)" \
  "Jobs Token" \
  "JOBS" \
  1000000000000000000000000000 \
  0xYOUR_ADMIN_ADDRESS

# Zatim verificiraj
forge verify-contract \
  --chain-id 11155111 \
  --num-of-optimizations 200 \
  --watch \
  --constructor-args $(cast abi-encode "constructor(string,string,uint256,address)" "Jobs Token" "JOBS" 1000000000000000000000000000 $ADMIN_ADDRESS) \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  $TOKEN_ADDRESS \
  src/tokens/erc20/JobsTokenFullV2.sol:JobsTokenFullV2
```

#### 3. Verificiraj JobsTokenStaking

```bash
# Constructor: (address stakingToken_, address rewardToken_, address admin_)
forge verify-contract \
  --chain-id 11155111 \
  --num-of-optimizations 200 \
  --watch \
  --constructor-args $(cast abi-encode "constructor(address,address,address)" $TOKEN_ADDRESS $TOKEN_ADDRESS $ADMIN_ADDRESS) \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  $STAKING_ADDRESS \
  src/tokens/staking/JobsTokenStaking.sol:JobsTokenStaking
```

#### 4. Verificiraj JobsTokenVestingERC20

```bash
# Constructor: (address token_, address admin_)
forge verify-contract \
  --chain-id 11155111 \
  --num-of-optimizations 200 \
  --watch \
  --constructor-args $(cast abi-encode "constructor(address,address)" $TOKEN_ADDRESS $ADMIN_ADDRESS) \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  $VESTING_ADDRESS \
  src/tokens/vesting/JobsTokenVestingERC20.sol:JobsTokenVestingERC20
```

**Kada završiš:** Kontrakti će biti vidljivi na Etherscanu sa source code-om i mogućnošću interakcije.

---

### 🔒 **PRIORITET 2: Security Audit** (1-2 tjedna)

**Zašto:** Prije mainnet deploymenta, moraš provjeriti sigurnost kontrakata.

#### Opcija A: Automatski Alati (Brzo - 1 dan)

**1. Instaliraj Slither:**

```bash
# Python 3.8+ required
pip install slither-analyzer

# Ili s virtualenv
python3 -m venv venv
source venv/bin/activate
pip install slither-analyzer
```

**2. Pokreni Analizu:**

```bash
# Analiziraj sve kontrakte
slither .

# Analiziraj specifičan kontrakt
slither src/tokens/staking/JobsTokenStaking.sol

# Sa detaljnim izvještajem
slither . --print human-summary

# Export u JSON
slither . --json slither-report.json

# Provjeri samo kritične issue-e
slither . --exclude-dependencies --exclude-optimization
```

**3. Mythril (Opcionalno):**

```bash
pip install mythril
mythril analyze src/tokens/staking/JobsTokenStaking.sol

# Sa detaljnim izvještajem
mythril analyze src/tokens/staking/JobsTokenStaking.sol --execution-timeout 300
```

**4. Solhint (Linting):**

```bash
npm install -g solhint
solhint "src/**/*.sol"
```

#### Opcija B: Profesionalni Audit (Preporučeno za Mainnet)

**Kada:** Prije mainnet deploymenta, obavezno profesionalni audit.

**Opcije:**
- **OpenZeppelin Security Services** - https://openzeppelin.com/security-audits/
- **Trail of Bits** - https://www.trailofbits.com/
- **Consensys Diligence** - https://consensys.io/diligence/
- **CertiK** - https://www.certik.com/
- **Quantstamp** - https://quantstamp.com/

**Što provjeriti:**
- ✅ Reentrancy napadi
- ✅ Access control provjere
- ✅ Integer overflow/underflow
- ✅ Front-running zaštita
- ✅ Edge cases u rewards distribuciji
- ✅ Vesting calculation accuracy
- ✅ Gas optimization
- ✅ Centralization risks

---

### 🎨 **PRIORITET 3: Frontend Integracija** (1-2 tjedna)

**Zašto:** Da korisnici mogu koristiti tvoje kontrakte kroz UI.

#### Korak 1: Export ABI-ja

```bash
# Build kontrakte
forge build

# ABI-ji su u:
# - out/JobsTokenFullV2.sol/JobsTokenFullV2.json
# - out/JobsTokenStaking.sol/JobsTokenStaking.json
# - out/JobsTokenVestingERC20.sol/JobsTokenVestingERC20.json

# Kopiraj ABI-je u frontend projekt
mkdir -p frontend/abis
cp out/JobsTokenFullV2.sol/JobsTokenFullV2.json frontend/abis/
cp out/JobsTokenStaking.sol/JobsTokenStaking.json frontend/abis/
cp out/JobsTokenVestingERC20.sol/JobsTokenVestingERC20.json frontend/abis/
```

#### Korak 2: Kreiraj Frontend Projekt

```bash
npx create-next-app@latest jobs-token-dapp --typescript --tailwind --app
cd jobs-token-dapp

# Instaliraj Web3 dependencies
npm install wagmi viem @rainbow-me/rainbowkit
npm install -D @types/node
```

#### Korak 3: Setup Wagmi Config

```typescript
// app/providers.tsx
'use client'

import { WagmiProvider } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { RainbowKitProvider } from '@rainbow-me/rainbowkit'
import { config } from './wagmi.config'

const queryClient = new QueryClient()

export function Providers({ children }: { children: React.ReactNode }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <RainbowKitProvider>
          {children}
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  )
}
```

```typescript
// app/wagmi.config.ts
import { getDefaultConfig } from '@rainbow-me/rainbowkit'
import { sepolia, mainnet } from 'wagmi/chains'

export const config = getDefaultConfig({
  appName: 'Jobs Token dApp',
  projectId: 'YOUR_PROJECT_ID', // WalletConnect project ID
  chains: [sepolia, mainnet],
  ssr: true,
})
```

#### Korak 4: Implementiraj Staking UI

```typescript
// components/Staking.tsx
'use client'

import { useAccount, useContractRead, useContractWrite, useWaitForTransaction } from 'wagmi'
import { parseEther, formatEther } from 'viem'
import JobsTokenStakingABI from '../abis/JobsTokenStaking.json'

const STAKING_ADDRESS = '0x...' // Tvoja staking adresa

export function StakingComponent() {
  const { address, isConnected } = useAccount()
  
  // Read staked balance
  const { data: stakedBalance } = useContractRead({
    address: STAKING_ADDRESS,
    abi: JobsTokenStakingABI.abi,
    functionName: 'balanceOf',
    args: [address!],
    enabled: !!address,
  })
  
  // Read pending rewards
  const { data: pendingRewards } = useContractRead({
    address: STAKING_ADDRESS,
    abi: JobsTokenStakingABI.abi,
    functionName: 'pendingRewards',
    args: [address!],
    enabled: !!address,
  })
  
  // Stake function
  const { write: stake, data: stakeData } = useContractWrite({
    address: STAKING_ADDRESS,
    abi: JobsTokenStakingABI.abi,
    functionName: 'stake',
  })
  
  const { isLoading: isStaking } = useWaitForTransaction({
    hash: stakeData?.hash,
  })
  
  const handleStake = (amount: string) => {
    stake({ args: [parseEther(amount)] })
  }
  
  return (
    <div>
      <h2>Staking</h2>
      {isConnected && (
        <>
          <p>Staked: {stakedBalance ? formatEther(stakedBalance) : '0'} JOBS</p>
          <p>Pending Rewards: {pendingRewards ? formatEther(pendingRewards) : '0'} JOBS</p>
          <button onClick={() => handleStake('100')} disabled={isStaking}>
            {isStaking ? 'Staking...' : 'Stake 100 JOBS'}
          </button>
        </>
      )}
    </div>
  )
}
```

#### Korak 5: Deploy na Vercel

```bash
# Build
npm run build

# Deploy
vercel deploy

# Ili kroz Vercel dashboard
# Push na GitHub i connect repo
```

---

### 📊 **PRIORITET 4: Monitoring Setup** (1 dan)

**Zašto:** Da pratiš stanje kontrakata u realnom vremenu.

#### Opcija 1: Tenderly (Preporučeno)

```bash
# Instaliraj Tenderly CLI
npm install -g tenderly

# Login
tenderly login

# Add projekt
tenderly init
tenderly devops init

# Monitor kontrakte
tenderly monitor
```

**Features:**
- Real-time monitoring
- Alerting za greške
- Gas tracking
- Transaction debugging

#### Opcija 2: OpenZeppelin Defender

```bash
# Instaliraj Defender CLI
npm install -g @openzeppelin/defender-cli

# Setup
defender init

# Create monitor
defender monitor create --name "JobsTokenStaking" --address $STAKING_ADDRESS
```

**Features:**
- Monitoring i automation
- Admin functions automation
- Multi-sig integration

#### Opcija 3: Custom Dashboard

```typescript
// components/Monitoring.tsx
import { useContractRead } from 'wagmi'

export function MonitoringDashboard() {
  const { data: totalStaked } = useContractRead({
    address: STAKING_ADDRESS,
    abi: JobsTokenStakingABI.abi,
    functionName: 'totalStaked',
  })
  
  // ... više metrics
  
  return (
    <div>
      <h2>Monitoring</h2>
      <p>Total Staked: {totalStaked ? formatEther(totalStaked) : '0'}</p>
      {/* Više metrics... */}
    </div>
  )
}
```

**Što pratiti:**
- Total staked amount
- Active stakers count
- Rewards distributed
- Vesting claims
- Contract events
- Error occurrences
- Gas usage

---

### 🚢 **PRIORITET 5: Production Deployment Checklist** (1 dan)

**Prije Mainnet Deploymenta:**

#### Pre-Deployment Checklist

- [ ] Security audit prošao ✅
- [ ] Svi testovi prolaze (87 testova) ✅
- [ ] Kontrakti verificirani na testnetu
- [ ] Gas optimization provjeren
- [ ] Admin keys sigurno pohranjeni (hardware wallet)
- [ ] Multisig setup za admin role (preporučeno)
- [ ] Emergency pause plan dokumentiran
- [ ] Frontend testiran na testnetu
- [ ] Dokumentacija ažurirana ✅
- [ ] Backup deployment skripte ✅
- [ ] RPC endpoints setup (Infura/Alchemy)
- [ ] Monitoring setup ✅

#### Multisig Setup (Preporučeno)

**Zašto:** Da ne budeš single point of failure.

**Opcije:**
- **Gnosis Safe** - https://gnosis-safe.io/
- **OpenZeppelin Defender** - https://defender.openzeppelin.com/

**Koraci:**
1. Kreiraj multisig wallet (npr. 2/3 ili 3/5)
2. Deploy kontrakte s multisig kao admin
3. Transfer admin role na multisig
4. Renounce admin role s originalnog walleta

#### Mainnet Deployment

```bash
# 1. Deploy na mainnet
forge script src/tokens/script/deploy/DeployJobsTokenFullV2.s.sol:DeployJobsTokenFullV2 \
  --rpc-url $MAINNET_RPC \
  --broadcast \
  --verify \
  --slow \
  --private-key $PRIVATE_KEY

# 2. Verificiraj kontrakte
# 3. Setup roles i permissions
# 4. Transfer admin role na multisig
# 5. Test s malim iznosima (smoke test)
```

#### Post-Deployment

- [ ] Verificiraj sve kontrakte na Etherscan
- [ ] Test s malim iznosima
- [ ] Provjeri sve role assignments
- [ ] Setup monitoring
- [ ] Announce na Twitter/Discord
- [ ] Update dokumentaciju s mainnet adresama

---

## 🎯 Preporučeni Redoslijed (Timeline)

### **Tjedan 1:**
- ✅ **Dan 1:** Verifikacija kontrakata (1-2 sata)
- ✅ **Dan 2:** Automatski security audit (1 dan)
- ✅ **Dan 3:** Gas optimization provjera (1 dan)
- ✅ **Dan 4-5:** Frontend setup (počni s osnovnim UI-om)

### **Tjedan 2-3:**
- ✅ **Tjedan 2:** Frontend integracija (kompletna implementacija)
- ✅ **Tjedan 3:** Testiranje na testnetu (1 tjedan)

### **Tjedan 4:**
- ✅ **Tjedan 4:** Profesionalni security audit (ako planiraš mainnet)
- ✅ **Tjedan 4:** Production deployment checklist
- ✅ **Tjedan 4:** Mainnet deployment (ako je sve spremno)

---

## 🛠️ Quick Start Commands

### Verifikacija
```bash
# JobsTokenFullV2
forge verify-contract --chain-id 11155111 \
  $TOKEN_ADDRESS \
  src/tokens/erc20/JobsTokenFullV2.sol:JobsTokenFullV2 \
  --constructor-args $(cast abi-encode "constructor(string,string,uint256,address)" "Jobs Token" "JOBS" 1000000000000000000000000000 $ADMIN_ADDRESS) \
  --etherscan-api-key $ETHERSCAN_API_KEY

# JobsTokenStaking
forge verify-contract --chain-id 11155111 \
  $STAKING_ADDRESS \
  src/tokens/staking/JobsTokenStaking.sol:JobsTokenStaking \
  --constructor-args $(cast abi-encode "constructor(address,address,address)" $TOKEN_ADDRESS $TOKEN_ADDRESS $ADMIN_ADDRESS) \
  --etherscan-api-key $ETHERSCAN_API_KEY

# JobsTokenVestingERC20
forge verify-contract --chain-id 11155111 \
  $VESTING_ADDRESS \
  src/tokens/vesting/JobsTokenVestingERC20.sol:JobsTokenVestingERC20 \
  --constructor-args $(cast abi-encode "constructor(address,address)" $TOKEN_ADDRESS $ADMIN_ADDRESS) \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

### Security Audit
```bash
# Slither
slither . --print human-summary

# Mythril
mythril analyze src/tokens/staking/JobsTokenStaking.sol
```

### Testovi
```bash
# Svi testovi
forge test

# Fuzz testovi
forge test --match-contract ".*Fuzz.*"

# Invariant testovi
forge test --match-contract ".*Invariant.*"

# Sa gas reportom
forge test --gas-report

# Verbose output
forge test -vvv
```

### Build
```bash
# Build sve kontrakte
forge build

# Build specifičan kontrakt
forge build --contracts src/tokens/staking/JobsTokenStaking.sol
```

---

## 📚 Korisni Linkovi

### Dokumentacija
- **Foundry Docs:** https://book.getfoundry.sh/
- **OpenZeppelin Docs:** https://docs.openzeppelin.com/
- **Etherscan API:** https://etherscan.io/apis
- **Slither Docs:** https://github.com/crytic/slither
- **Wagmi Docs:** https://wagmi.sh/
- **RainbowKit Docs:** https://www.rainbowkit.com/

### Alati
- **Etherscan:** https://etherscan.io/
- **Tenderly:** https://tenderly.co/
- **OpenZeppelin Defender:** https://defender.openzeppelin.com/
- **Gnosis Safe:** https://gnosis-safe.io/
- **Vercel:** https://vercel.com/

---

## 💡 Dodatne Ideje (Opcionalno)

### Proširenja:
- **Staking tiers** - različiti APY ovisno o količini stakea
- **Lock periods** - veći rewards za duže lock periode
- **Referral system** - rewards za referale
- **Governance** - DAO voting za parametre
- **NFT rewards** - NFT-ovi kao dodatni rewards
- **Multi-token staking** - stake više tokena odjednom

### Marketing:
- **Documentation website** - deploy na Vercel
- **Video tutoriali** - kako koristiti staking/vesting
- **Community building** - Discord, Twitter
- **Blog posts** - technical deep dives

---

## ✅ Status Tracking

Koristi ovu tablicu da pratiš napredak:

| Task | Status | Notes |
|------|--------|-------|
| Verifikacija kontrakata | ⬜ | |
| Security audit (automatski) | ⬜ | |
| Security audit (profesionalni) | ⬜ | |
| Frontend integracija | ⬜ | |
| Monitoring setup | ⬜ | |
| Testnet testing | ⬜ | |
| Multisig setup | ⬜ | |
| Mainnet deployment | ⬜ | |

---

## 🎉 Sretno!

Imaš solidnu bazu - svi testovi prolaze, dokumentacija je kompletna, kontrakti su spremni. Sada je vrijeme da ih staviš u produkciju! 🚀

**Sljedeći korak:** Počni s verifikacijom kontrakata - to je najbrži i najlakši korak koji će ti dati najviše vrijednosti.

**Quick Win:** Verifikacija kontrakata možeš napraviti u **1-2 sata** i odmah ćeš imati transparentne, provjerljive kontrakte na Etherscanu!

