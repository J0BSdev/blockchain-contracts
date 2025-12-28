#!/bin/bash
# Simple cliff check script

VESTING_ADDRESS=${VESTING_ADDRESS:-""}
RPC_URL=${RPC_URL:-""}
WALLET=${WALLET:-""}
VESTING_ID=${VESTING_ID:-"0"}

if [ -z "$VESTING_ADDRESS" ] || [ -z "$RPC_URL" ] || [ -z "$WALLET" ]; then
    echo "Usage: VESTING_ADDRESS=0x... RPC_URL=... WALLET=0x... [VESTING_ID=0] ./check_cliff.sh"
    exit 1
fi

echo "=== Cliff Check ==="
echo ""

# Get cliff timestamp
echo "Getting cliff timestamp..."
CLIFF=$(cast call $VESTING_ADDRESS "vestings(address,uint256).cliff(uint64)" $WALLET $VESTING_ID --rpc-url $RPC_URL 2>&1)

if echo "$CLIFF" | grep -q "Error\|error\|revert"; then
    echo "❌ Error getting cliff. Check if vesting exists at ID $VESTING_ID"
    echo "   First check count: cast call $VESTING_ADDRESS \"vestingCount(address)(uint256)\" $WALLET --rpc-url $RPC_URL"
    exit 1
fi

echo "Cliff timestamp: $CLIFF"
echo ""

# Get current block timestamp
echo "Getting current block timestamp..."
CURRENT_HEX=$(cast rpc eth_getBlockByNumber latest true --rpc-url $RPC_URL 2>/dev/null | grep -o '"timestamp":"[^"]*"' | head -1 | cut -d'"' -f4)

if [ -z "$CURRENT_HEX" ]; then
    # Fallback to system time
    CURRENT=$(date +%s)
    echo "Using system time: $CURRENT"
else
    CURRENT=$(cast --to-dec $CURRENT_HEX 2>/dev/null || echo "$(date +%s)")
    echo "Block timestamp: $CURRENT"
fi

echo ""

# Compare
if [ -n "$CLIFF" ] && [ -n "$CURRENT" ]; then
    if [ "$CURRENT" -lt "$CLIFF" ]; then
        REMAINING=$((CLIFF - CURRENT))
        DAYS=$(echo "scale=2; $REMAINING / 86400" | bc 2>/dev/null || echo "N/A")
        echo "❌ Cliff period NOT reached yet!"
        echo "   Remaining: $REMAINING seconds (~$DAYS days)"
        echo "   Cliff will be reached: $(date -d @$CLIFF 2>/dev/null || echo "timestamp $CLIFF")"
    else
        PASSED=$((CURRENT - CLIFF))
        DAYS=$(echo "scale=2; $PASSED / 86400" | bc 2>/dev/null || echo "N/A")
        echo "✅ Cliff period PASSED!"
        echo "   Passed: $PASSED seconds (~$DAYS days ago)"
        echo "   Cliff was: $(date -d @$CLIFF 2>/dev/null || echo "timestamp $CLIFF")"
    fi
else
    echo "⚠️  Could not compare timestamps"
fi

