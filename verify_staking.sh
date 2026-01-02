#!/bin/bash
# Script za provjeru staking kontrakta nakon wiring-a

TOKEN_ADDRESS=${TOKEN_ADDRESS:-""}
STAKING_ADDRESS=${STAKING_ADDRESS:-""}
RPC_URL=${RPC_URL:-""}

if [ -z "$TOKEN_ADDRESS" ] || [ -z "$STAKING_ADDRESS" ] || [ -z "$RPC_URL" ]; then
    echo "Usage: TOKEN_ADDRESS=0x... STAKING_ADDRESS=0x... RPC_URL=... ./verify_staking.sh"
    exit 1
fi

echo "=== Staking Contract Verification ==="
echo ""

# 1. Provjeri rewards duration
echo "1. Rewards Duration:"
DURATION=$(cast call $STAKING_ADDRESS "rewardsDuration()(uint256)" --rpc-url $RPC_URL)
echo "   $DURATION seconds ($(echo "scale=2; $DURATION / 86400" | bc) days)"
echo ""

# 2. Provjeri period finish
echo "2. Reward Period:"
PERIOD_FINISH=$(cast call $STAKING_ADDRESS "periodFinish()(uint256)" --rpc-url $RPC_URL)
CURRENT_TIME=$(cast rpc eth_getBlockByNumber latest true --rpc-url $RPC_URL | grep -o '"timestamp":"[^"]*"' | head -1 | cut -d'"' -f4)
CURRENT_DEC=$(cast --to-dec $CURRENT_TIME 2>/dev/null || echo "$(date +%s)")

if [ "$PERIOD_FINISH" != "0" ] && [ -n "$CURRENT_DEC" ]; then
    if [ "$CURRENT_DEC" -lt "$PERIOD_FINISH" ]; then
        REMAINING=$((PERIOD_FINISH - CURRENT_DEC))
        echo "   ✅ Active! Period ends: $(date -d @$PERIOD_FINISH 2>/dev/null || echo "timestamp $PERIOD_FINISH")"
        echo "   Remaining: $REMAINING seconds ($(echo "scale=2; $REMAINING / 86400" | bc) days)"
    else
        echo "   ⚠️  Period expired. Need to top-up rewards."
    fi
else
    echo "   ⚠️  Period not set or could not fetch current time"
fi
echo ""

# 3. Provjeri reward rate
echo "3. Reward Rate:"
RATE=$(cast call $STAKING_ADDRESS "rewardRatePerSecond()(uint256)" --rpc-url $RPC_URL)
if [ "$RATE" != "0" ]; then
    RATE_PER_DAY=$(echo "scale=2; $RATE * 86400 / 1e18" | bc)
    echo "   $RATE wei/second"
    echo "   ≈ $RATE_PER_DAY tokens/day"
else
    echo "   ⚠️  No active reward rate"
fi
echo ""

# 4. Provjeri balance staking kontrakta
echo "4. Staking Contract Balance:"
BALANCE=$(cast call $TOKEN_ADDRESS "balanceOf(address)(uint256)" $STAKING_ADDRESS --rpc-url $RPC_URL)
echo "   $BALANCE wei ($(cast --to-unit $BALANCE ether) tokens)"
echo ""

# 5. Provjeri total staked
echo "5. Total Staked:"
TOTAL_STAKED=$(cast call $STAKING_ADDRESS "totalStaked()(uint256)" --rpc-url $RPC_URL)
echo "   $TOTAL_STAKED wei ($(cast --to-unit $TOTAL_STAKED ether) tokens)"
echo ""

# 6. Provjeri available rewards
echo "6. Available Rewards (balance - totalStaked):"
if [ -n "$BALANCE" ] && [ -n "$TOTAL_STAKED" ]; then
    if [ "$BALANCE" -gt "$TOTAL_STAKED" ]; then
        AVAILABLE=$((BALANCE - TOTAL_STAKED))
        echo "   ✅ $AVAILABLE wei ($(cast --to-unit $AVAILABLE ether) tokens available)"
    else
        echo "   ⚠️  No available rewards (balance <= totalStaked)"
    fi
fi
echo ""

# 7. Provjeri accRewardPerShare
echo "7. Accumulated Reward Per Share:"
ACC=$(cast call $STAKING_ADDRESS "accRewardPerShare()(uint256)" --rpc-url $RPC_URL)
echo "   $ACC (scaled by 1e18)"
echo ""

echo "=== Summary ==="
if [ "$PERIOD_FINISH" != "0" ] && [ "$RATE" != "0" ]; then
    echo "✅ Staking is active and ready!"
    echo "   Users can now stake tokens and earn rewards"
else
    echo "⚠️  Staking may not be fully configured"
    echo "   Check periodFinish and rewardRatePerSecond"
fi

