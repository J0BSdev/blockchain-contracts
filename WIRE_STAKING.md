# 🔗 Wire Staking Contract - Complete Guide

## 📋 Što trebaš napraviti

Novi staking kontrakt koristi **prefunded pool model** - admin mora transferirati reward tokene u staking kontrakt PRIJE aktivacije rewards.

---

## 🚀 Koraci za povezivanje

### 1. Postavi Environment Variables

```bash
export PRIVATE_KEY=0x...          # Tvoj deployer private key
export TOKEN_ADDRESS=0x...        # JobsTokenFullV2 address
export STAKING_ADDRESS=0x...      # JobsTokenStaking address
export REWARD_AMOUNT=1000000e18  # Koliko tokena želiš distribuirati kao rewards
export REWARDS_DURATION=604800    # Optional: duration u sekundama (default: 7 dana)
```

**Primjer:**
```bash
export REWARD_AMOUNT=1000000e18   # 1M tokena
export REWARDS_DURATION=604800    # 7 dana (7 * 24 * 60 * 60)
```

---

### 2. Pokreni Wire Script

```bash
forge script src/tokens/script/deploy/WireJobsERC20.s.sol:WireJobsERC20 \
  --rpc-url $RPC_URL \
  --broadcast \
  -vvv
```

---

## 📝 Što script radi

1. **Postavlja rewards duration** (ako je custom, default je 7 dana)
2. **Transferira reward tokene** u staking kontrakt (prefund)
3. **Aktivira rewards** pozivom `notifyRewardAmount()`

---

## ⚠️ Važno

### Prefundiranje
- Admin mora imati dovoljno tokena na svom walletu
- Tokene mora transferirati u staking kontrakt PRIJE pozivanja `notifyRewardAmount()`
- Script automatski radi transfer

### Reward Rate
- Rate se automatski računa: `rewardRatePerSecond = rewardAmount / rewardsDuration`
- Primjer: 1M tokena / 7 dana = ~1.65 tokena/sekundu

### Safety
- Staking kontrakt **NIKADA ne troši principal** (staked tokens)
- Koristi samo `availableRewards = balance - totalStaked`
- Ako nema dovoljno prefunded rewards, `notifyRewardAmount()` će revertati

---

## 🧪 Provjere nakon wiring-a

### 1. Provjeri da li su rewards aktivni
```bash
cast call $STAKING_ADDRESS "periodFinish()(uint256)" --rpc-url $RPC_URL
# Trebao bi biti > block.timestamp
```

### 2. Provjeri reward rate
```bash
cast call $STAKING_ADDRESS "rewardRatePerSecond()(uint256)" --rpc-url $RPC_URL
```

### 3. Provjeri available rewards
```bash
# Balance staking kontrakta
cast call $TOKEN_ADDRESS "balanceOf(address)(uint256)" $STAKING_ADDRESS --rpc-url $RPC_URL

# Total staked
cast call $STAKING_ADDRESS "totalStaked()(uint256)" --rpc-url $RPC_URL

# Available = balance - totalStaked
```

### 4. Provjeri rewards duration
```bash
cast call $STAKING_ADDRESS "rewardsDuration()(uint256)" --rpc-url $RPC_URL
```

---

## 🔄 Top-up Rewards (dodatno prefundiranje)

Ako želiš dodati više rewards dok je period aktivan:

1. **Transfer dodatne tokene** u staking kontrakt
2. **Pozovi `notifyRewardAmount()`** s novim iznosom
3. Kontrakt će automatski kombinirati leftover + novi rewards

**Primjer:**
```bash
# Transfer dodatnih 500k tokena
cast send $TOKEN_ADDRESS "transfer(address,uint256)" $STAKING_ADDRESS 500000e18 \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL

# Aktiviraj nove rewards
cast send $STAKING_ADDRESS "notifyRewardAmount(uint256)" 500000e18 \
  --private-key $PRIVATE_KEY --rpc-url $RPC_URL
```

---

## 📊 Formula za Reward Rate

```
rewardRatePerSecond = rewardAmount / rewardsDuration

Primjer:
- rewardAmount = 1,000,000e18 (1M tokena)
- rewardsDuration = 604,800 (7 dana)
- rewardRatePerSecond = 1,000,000e18 / 604,800 ≈ 1.65e18 tokena/sekundu
```

---

## ✅ Checklist

- [ ] Postavljene sve env varijable
- [ ] Admin ima dovoljno tokena za prefundiranje
- [ ] Pokrenut wire script
- [ ] Provjereno da su rewards aktivni (`periodFinish > now`)
- [ ] Provjeren reward rate
- [ ] Provjeren available rewards pool

---

## 🆘 Troubleshooting

**Problem:** `notifyRewardAmount()` reverta
**Rješenje:** Provjeri da li imaš dovoljno tokena prefundiranih u staking kontrakt

**Problem:** Reward rate je 0
**Rješenje:** Provjeri da li je `rewardsDuration` postavljen i da li je `rewardAmount > 0`

**Problem:** Period nije aktivan
**Rješenje:** Provjeri `periodFinish` - trebao bi biti > `block.timestamp`

