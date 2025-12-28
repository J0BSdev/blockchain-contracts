#!/bin/bash
# Detailed vesting check script

VESTING_ADDRESS=${VESTING_ADDRESS:-""}
RPC_URL=${RPC_URL:-""}
WALLET=${WALLET:-""}
VESTING_ID=${VESTING_ID:-"0"}

if [ -z "$VESTING_ADDRESS" ] || [ -z "$RPC_URL" ] || [ -z "$WALLET" ]; then
    echo "Usage: VESTING_ADDRESS=0x... RPC_URL=... WALLET=0x... [VESTING_ID=0] ./check_vesting.sh"
    exit 1
fi

echo "=== Detailed Vesting Check ==="
echo "Wallet: $WALLET"
echo "Vesting ID: $VESTING_ID"
echo ""

# 1. Check count
echo "1. Vesting count:"
COUNT=$(cast call $VESTING_ADDRESS "vestingCount(address)(uint256)" $WALLET --rpc-url $RPC_URL)
echo "   $COUNT vesting(s)"
echo ""

if [ "$COUNT" = "0" ]; then
    echo "❌ No vestings found! Create a vesting first."
    exit 0
fi

if [ "$VESTING_ID" -ge "$COUNT" ]; then
    echo "❌ Vesting ID $VESTING_ID doesn't exist. Max ID is $((COUNT - 1))"
    exit 1
fi

# 2. Get current block timestamp
echo "2. Current block timestamp:"
CURRENT_TIME=$(cast rpc eth_getBlockByNumber latest true --rpc-url $RPC_URL 2>/dev/null | grep -o '"timestamp":"[^"]*"' | head -1 | cut -d'"' -f4)
if [ -z "$CURRENT_TIME" ]; then
    # Fallback: try to get from block
    CURRENT_TIME=$(cast block latest --rpc-url $RPC_URL 2>/dev/null | grep -i timestamp | awk '{print $2}' || echo "")
fi
if [ -n "$CURRENT_TIME" ]; then
    # Convert hex to decimal if needed
    if [[ "$CURRENT_TIME" == 0x* ]]; then
        CURRENT_TIME=$(cast --to-dec $CURRENT_TIME)
    fi
    echo "   $CURRENT_TIME ($(date -d @$CURRENT_TIME 2>/dev/null || echo "timestamp"))"
else
    echo "   Could not fetch timestamp"
    CURRENT_TIME=$(date +%s)
    echo "   Using system time: $CURRENT_TIME"
fi
echo ""

# 3. Get vesting details
echo "3. Vesting details:"
TOTAL=$(cast call $VESTING_ADDRESS "vestings(address,uint256).total(uint128)" $WALLET $VESTING_ID --rpc-url $RPC_URL)
CLAIMED=$(cast call $VESTING_ADDRESS "vestings(address,uint256).claimed(uint128)" $WALLET $VESTING_ID --rpc-url $RPC_URL)
START=$(cast call $VESTING_ADDRESS "vestings(address,uint256).start(uint64)" $WALLET $VESTING_ID --rpc-url $RPC_URL)
CLIFF=$(cast call $VESTING_ADDRESS "vestings(address,uint256).cliff(uint64)" $WALLET $VESTING_ID --rpc-url $RPC_URL)
DURATION=$(cast call $VESTING_ADDRESS "vestings(address,uint256).duration(uint64)" $WALLET $VESTING_ID --rpc-url $RPC_URL)
REVOKED=$(cast call $VESTING_ADDRESS "vestings(address,uint256).revoked(bool)" $WALLET $VESTING_ID --rpc-url $RPC_URL)

echo "   Total: $TOTAL"
echo "   Claimed: $CLAIMED"
echo "   Start: $START ($(date -d @$START 2>/dev/null || echo "timestamp"))"
echo "   Cliff: $CLIFF ($(date -d @$CLIFF 2>/dev/null || echo "timestamp"))"
echo "   Duration: $DURATION seconds ($(echo "scale=2; $DURATION / 86400" | bc) days)"
echo "   Revoked: $REVOKED"
echo ""

# 4. Check vested amount
echo "4. Vested amount:"
VESTED=$(cast call $VESTING_ADDRESS "vestedAmount(address,uint256)(uint256)" $WALLET $VESTING_ID --rpc-url $RPC_URL)
echo "   $VESTED"
echo ""

# 5. Check why it might be 0
echo "5. Analysis:"
if [ "$VESTED" = "0" ]; then
    if [ "$CURRENT_TIME" -lt "$CLIFF" ]; then
        CLIFF_REMAINING=$((CLIFF - CURRENT_TIME))
        echo "   ⚠️  Cliff period not reached yet!"
        echo "   ⚠️  Remaining: $CLIFF_REMAINING seconds ($(echo "scale=2; $CLIFF_REMAINING / 86400" | bc) days)"
        echo "   ⚠️  Cliff will be reached: $(date -d @$CLIFF 2>/dev/null || echo "timestamp")"
    elif [ "$TOTAL" = "0" ]; then
        echo "   ⚠️  Total is 0 - vesting might not be properly initialized"
    else
        echo "   ⚠️  Vested is 0 but cliff passed - check vesting parameters"
    fi
else
    CLAIMABLE=$((VESTED - CLAIMED))
    echo "   ✅ Vested: $VESTED"
    echo "   ✅ Claimed: $CLAIMED"
    echo "   ✅ Claimable: $CLAIMABLE"
    if [ "$CLAIMABLE" -gt "0" ]; then
        echo "   💰 You can claim $CLAIMABLE tokens!"
    else
        echo "   ℹ️  All vested tokens have been claimed"
    fi
fi
echo ""

# 6. End time
END_TIME=$((START + DURATION))
echo "6. Vesting schedule:"
echo "   Start: $(date -d @$START 2>/dev/null || echo $START)"
echo "   Cliff: $(date -d @$CLIFF 2>/dev/null || echo $CLIFF)"
echo "   End: $(date -d @$END_TIME 2>/dev/null || echo $END_TIME)"
if [ "$CURRENT_TIME" -lt "$END_TIME" ]; then
    REMAINING=$((END_TIME - CURRENT_TIME))
    echo "   Remaining: $REMAINING seconds ($(echo "scale=2; $REMAINING / 86400" | bc) days)"
else
    echo "   ✅ Vesting period completed"
fi

