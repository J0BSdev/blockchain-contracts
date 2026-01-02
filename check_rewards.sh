#!/bin/bash
# Brza provjera rewards u staking kontraktu

TOKEN_ADDRESS=${TOKEN_ADDRESS:-""}
STAKING_ADDRESS=${STAKING_ADDRESS:-""}
RPC_URL=${RPC_URL:-""}

if [ -z "$TOKEN_ADDRESS" ] || [ -z "$STAKING_ADDRESS" ] || [ -z "$RPC_URL" ]; then
    echo "Usage: TOKEN_ADDRESS=0x... STAKING_ADDRESS=0x... RPC_URL=... ./check_rewards.sh"
    exit 1
fi

echo "=== Provjera Rewards u Staking Kontraktu ==="
echo ""

# Provjeri balance
echo "1. Staking Contract Balance:"
BALANCE=$(cast call $TOKEN_ADDRESS "balanceOf(address)(uint256)" $STAKING_ADDRESS --rpc-url $RPC_URL 2>/dev/null | awk '{print $1}')
echo "   $BALANCE wei"
if [ -n "$BALANCE" ] && [ "$BALANCE" != "0" ]; then
    BALANCE_ETHER=$(echo "scale=6; $BALANCE / 1000000000000000000" | bc 2>/dev/null)
    echo "   ≈ $BALANCE_ETHER tokens"
else
    echo "   ⚠️  Balance je 0 - nema tokena!"
fi
echo ""

# Provjeri total staked
echo "2. Total Staked:"
STAKED=$(cast call $STAKING_ADDRESS "totalStaked()(uint256)" --rpc-url $RPC_URL 2>/dev/null | awk '{print $1}')
echo "   $STAKED wei"
if [ -n "$STAKED" ] && [ "$STAKED" != "0" ]; then
    STAKED_ETHER=$(echo "scale=6; $STAKED / 1000000000000000000" | bc 2>/dev/null)
    echo "   ≈ $STAKED_ETHER tokens"
fi
echo ""

# Izračunaj available rewards
echo "3. Available Rewards (balance - totalStaked):"
if [ -n "$BALANCE" ] && [ -n "$STAKED" ] && [[ "$BALANCE" =~ ^[0-9]+$ ]] && [[ "$STAKED" =~ ^[0-9]+$ ]]; then
    if [ "$BALANCE" -gt "$STAKED" ]; then
        AVAILABLE=$(echo "$BALANCE - $STAKED" | bc 2>/dev/null)
        AVAILABLE_ETHER=$(echo "scale=6; $AVAILABLE / 1000000000000000000" | bc 2>/dev/null)
        echo "   ✅ $AVAILABLE wei"
        if [ -n "$AVAILABLE_ETHER" ]; then
            echo "   ≈ $AVAILABLE_ETHER tokens available"
        fi
    else
        echo "   ⚠️  No available rewards"
        echo "   Balance: $BALANCE wei"
        echo "   Staked: $STAKED wei"
    fi
else
    echo "   ⚠️  Could not calculate"
fi
echo ""

# Summary
echo "=== Summary ==="
if [ -n "$BALANCE" ] && [ "$BALANCE" != "0" ]; then
    if [ -n "$STAKED" ] && [[ "$BALANCE" =~ ^[0-9]+$ ]] && [[ "$STAKED" =~ ^[0-9]+$ ]] && [ "$BALANCE" -gt "$STAKED" ]; then
        AVAILABLE=$(echo "$BALANCE - $STAKED" | bc 2>/dev/null)
        echo "✅ Staking kontrakt ima rewards!"
        echo "   Available: $AVAILABLE wei"
    else
        echo "⚠️  Balance postoji ali sve je stakano"
    fi
else
    echo "❌ Nema tokena u staking kontraktu!"
    echo "   Trebaš prefundirati rewards"
fi

