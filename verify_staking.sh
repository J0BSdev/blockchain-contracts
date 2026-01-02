#!/bin/bash
# Script za provjeru staking kontrakta nakon wiring-a

TOKEN_ADDRESS=${TOKEN_ADDRESS:-""}
STAKING_ADDRESS=${STAKING_ADDRESS:-""}
RPC_URL=${RPC_URL:-""}

if [ -z "$TOKEN_ADDRESS" ] || [ -z "$STAKING_ADDRESS" ] || [ -z "$RPC_URL" ]; then
    echo "Usage: TOKEN_ADDRESS=0x... STAKING_ADDRESS=0x... RPC_URL=... ./verify_staking.sh"
    exit 1
fi

# Provjeri da li bc postoji
if ! command -v bc &> /dev/null; then
    echo "Warning: 'bc' command not found. Some calculations may be limited."
    echo "Install with: sudo apt-get install bc (Ubuntu/Debian) or sudo yum install bc (RHEL/CentOS)"
    echo ""
fi

echo "=== Staking Contract Verification ==="
echo ""

# Helper function to extract number from cast output (removes formatting like [1e21])
extract_number() {
    local input="$1"
    # Remove brackets and scientific notation, extract first number
    echo "$input" | sed 's/\[.*\]//' | awk '{print $1}' | grep -oE '^[0-9]+$' || echo "0"
}

# 1. Provjeri rewards duration
echo "1. Rewards Duration:"
DURATION_RAW=$(cast call $STAKING_ADDRESS "rewardsDuration()(uint256)" --rpc-url $RPC_URL 2>/dev/null)
DURATION=$(extract_number "$DURATION_RAW")
if [ -n "$DURATION" ] && [[ "$DURATION" =~ ^[0-9]+$ ]]; then
    DURATION_DAYS=$(echo "scale=2; $DURATION / 86400" | bc 2>/dev/null)
    echo "   $DURATION seconds"
    if [ -n "$DURATION_DAYS" ]; then
        echo "   ≈ $DURATION_DAYS days"
    fi
else
    echo "   ⚠️  Could not fetch duration"
    DURATION="0"
fi
echo ""

# 2. Provjeri period finish
echo "2. Reward Period:"
PERIOD_FINISH_RAW=$(cast call $STAKING_ADDRESS "periodFinish()(uint256)" --rpc-url $RPC_URL 2>/dev/null)
PERIOD_FINISH=$(extract_number "$PERIOD_FINISH_RAW")
CURRENT_TIME_RAW=$(cast rpc eth_getBlockByNumber latest true --rpc-url $RPC_URL 2>/dev/null | grep -o '"timestamp":"[^"]*"' | head -1 | cut -d'"' -f4)
CURRENT_TIME_HEX=${CURRENT_TIME_RAW:-"0x0"}
CURRENT_DEC=$(cast --to-dec $CURRENT_TIME_HEX 2>/dev/null || echo "$(date +%s)")

if [ -n "$PERIOD_FINISH" ] && [[ "$PERIOD_FINISH" =~ ^[0-9]+$ ]] && [ "$PERIOD_FINISH" != "0" ] && [ -n "$CURRENT_DEC" ] && [[ "$CURRENT_DEC" =~ ^[0-9]+$ ]]; then
    if [ "$CURRENT_DEC" -lt "$PERIOD_FINISH" ]; then
        REMAINING=$((PERIOD_FINISH - CURRENT_DEC))
        REMAINING_DAYS=$(echo "scale=2; $REMAINING / 86400" | bc 2>/dev/null)
        echo "   ✅ Active! Period ends: $(date -d @$PERIOD_FINISH 2>/dev/null || echo "timestamp $PERIOD_FINISH")"
        echo "   Remaining: $REMAINING seconds"
        if [ -n "$REMAINING_DAYS" ]; then
            echo "   ≈ $REMAINING_DAYS days"
        fi
    else
        echo "   ⚠️  Period expired. Need to top-up rewards."
        echo "   Period ended: $(date -d @$PERIOD_FINISH 2>/dev/null || echo "timestamp $PERIOD_FINISH")"
    fi
else
    echo "   ⚠️  Period not set or could not fetch current time"
    PERIOD_FINISH="0"
fi
echo ""

# 3. Provjeri reward rate
echo "3. Reward Rate:"
RATE_RAW=$(cast call $STAKING_ADDRESS "rewardRatePerSecond()(uint256)" --rpc-url $RPC_URL 2>/dev/null)
RATE=$(extract_number "$RATE_RAW")
if [ -n "$RATE" ] && [[ "$RATE" =~ ^[0-9]+$ ]] && [ "$RATE" != "0" ]; then
    RATE_PER_SEC=$(echo "scale=10; $RATE / 1000000000000000000" | bc 2>/dev/null)
    if [ -n "$RATE_PER_SEC" ]; then
        RATE_PER_DAY=$(echo "scale=6; $RATE_PER_SEC * 86400" | bc 2>/dev/null)
        echo "   $RATE wei/second"
        echo "   ≈ $RATE_PER_SEC tokens/second"
        if [ -n "$RATE_PER_DAY" ]; then
            echo "   ≈ $RATE_PER_DAY tokens/day"
        fi
    else
        echo "   $RATE wei/second"
    fi
else
    echo "   ⚠️  No active reward rate"
fi
echo ""

# 4. Provjeri balance staking kontrakta
echo "4. Staking Contract Balance:"
BALANCE_RAW=$(cast call $TOKEN_ADDRESS "balanceOf(address)(uint256)" $STAKING_ADDRESS --rpc-url $RPC_URL 2>/dev/null)
BALANCE=$(extract_number "$BALANCE_RAW")
if [ -n "$BALANCE" ] && [[ "$BALANCE" =~ ^[0-9]+$ ]]; then
    BALANCE_ETHER=$(echo "scale=6; $BALANCE / 1000000000000000000" | bc 2>/dev/null)
    echo "   $BALANCE wei"
    if [ -n "$BALANCE_ETHER" ]; then
        echo "   ≈ $BALANCE_ETHER tokens"
    fi
else
    echo "   ⚠️  Could not fetch balance"
    BALANCE="0"
fi
echo ""

# 5. Provjeri total staked
echo "5. Total Staked:"
TOTAL_STAKED_RAW=$(cast call $STAKING_ADDRESS "totalStaked()(uint256)" --rpc-url $RPC_URL 2>/dev/null)
TOTAL_STAKED=$(extract_number "$TOTAL_STAKED_RAW")
if [ -n "$TOTAL_STAKED" ] && [[ "$TOTAL_STAKED" =~ ^[0-9]+$ ]]; then
    STAKED_ETHER=$(echo "scale=6; $TOTAL_STAKED / 1000000000000000000" | bc 2>/dev/null)
    echo "   $TOTAL_STAKED wei"
    if [ -n "$STAKED_ETHER" ]; then
        echo "   ≈ $STAKED_ETHER tokens"
    fi
else
    echo "   ⚠️  Could not fetch total staked"
    TOTAL_STAKED="0"
fi
echo ""

# 6. Provjeri available rewards
echo "6. Available Rewards (balance - totalStaked):"
if [ -n "$BALANCE" ] && [ -n "$TOTAL_STAKED" ] && [[ "$BALANCE" =~ ^[0-9]+$ ]] && [[ "$TOTAL_STAKED" =~ ^[0-9]+$ ]]; then
    if [ "$BALANCE" -gt "$TOTAL_STAKED" ]; then
        AVAILABLE=$(echo "$BALANCE - $TOTAL_STAKED" | bc)
        if [ -n "$AVAILABLE" ] && [ "$AVAILABLE" != "0" ]; then
            AVAILABLE_ETHER=$(echo "scale=6; $AVAILABLE / 1000000000000000000" | bc 2>/dev/null)
            echo "   ✅ $AVAILABLE wei"
            if [ -n "$AVAILABLE_ETHER" ]; then
                echo "   ≈ $AVAILABLE_ETHER tokens available"
            fi
        else
            echo "   ⚠️  Calculation error"
        fi
    else
        echo "   ⚠️  No available rewards (balance <= totalStaked)"
    fi
else
    echo "   ⚠️  Could not fetch balance or staked amount"
fi
echo ""

# 7. Provjeri accRewardPerShare
echo "7. Accumulated Reward Per Share:"
ACC_RAW=$(cast call $STAKING_ADDRESS "accRewardPerShare()(uint256)" --rpc-url $RPC_URL 2>/dev/null)
ACC=$(extract_number "$ACC_RAW")
if [ -n "$ACC" ]; then
    echo "   $ACC (scaled by 1e18)"
else
    echo "   ⚠️  Could not fetch"
fi
echo ""

echo "=== Summary ==="
if [ -n "$PERIOD_FINISH" ] && [ -n "$RATE" ] && [[ "$PERIOD_FINISH" =~ ^[0-9]+$ ]] && [[ "$RATE" =~ ^[0-9]+$ ]] && [ "$PERIOD_FINISH" != "0" ] && [ "$RATE" != "0" ]; then
    if [ -n "$CURRENT_DEC" ] && [[ "$CURRENT_DEC" =~ ^[0-9]+$ ]] && [ "$CURRENT_DEC" -lt "$PERIOD_FINISH" ]; then
        if [ -n "$BALANCE" ] && [[ "$BALANCE" =~ ^[0-9]+$ ]] && [ "$BALANCE" != "0" ]; then
            echo "✅ Staking is active and ready!"
            echo "   Users can now stake tokens and earn rewards"
        else
            echo "⚠️  Reward period is active BUT no tokens in contract!"
            echo "   - Period: Active until $(date -d @$PERIOD_FINISH 2>/dev/null || echo "timestamp $PERIOD_FINISH")"
            echo "   - Rate: $RATE wei/second"
            echo "   - Balance: 0 wei (no rewards to pay out)"
            echo ""
            echo "💡 Action needed: Transfer reward tokens to staking contract"
            echo "   Then call notifyRewardAmount() to activate rewards"
        fi
    else
        echo "⚠️  Reward period expired"
        echo "   Need to top-up rewards with notifyRewardAmount()"
    fi
else
    echo "⚠️  Staking may not be fully configured"
    echo "   - Period finish: $PERIOD_FINISH"
    echo "   - Reward rate: $RATE"
    echo "   - Balance: $BALANCE wei"
    if [ "$BALANCE" = "0" ] || [ -z "$BALANCE" ]; then
        echo ""
        echo "💡 Tip: Prefund rewards by transferring tokens to staking contract"
        echo "   Then call notifyRewardAmount() to activate rewards"
    fi
fi

