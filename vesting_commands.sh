#!/bin/bash
# Helper commands for JobsTokenVestingERC20

VESTING_ADDRESS=${VESTING_ADDRESS:-""}
RPC_URL=${RPC_URL:-""}
WALLET=${WALLET:-""}
VESTING_ID=${VESTING_ID:-"0"}

if [ -z "$VESTING_ADDRESS" ] || [ -z "$RPC_URL" ]; then
    echo "Usage: VESTING_ADDRESS=0x... RPC_URL=... [WALLET=0x...] [VESTING_ID=0] ./vesting_commands.sh"
    exit 1
fi

echo "=== JobsTokenVestingERC20 Commands ==="
echo ""

# View functions (cast call)
echo "1. Check how many vestings user has:"
if [ -n "$WALLET" ]; then
    COUNT=$(cast call $VESTING_ADDRESS "vestingCount(address)(uint256)" $WALLET --rpc-url $RPC_URL)
    echo "   Vesting count: $COUNT"
    if [ "$COUNT" = "0" ]; then
        echo "   ⚠️  User has no vestings!"
    fi
else
    echo "   cast call $VESTING_ADDRESS \"vestingCount(address)(uint256)\" \$WALLET --rpc-url $RPC_URL"
fi
echo ""

echo "2. Check vested amount for specific vesting (view):"
if [ -n "$WALLET" ]; then
    COUNT=$(cast call $VESTING_ADDRESS "vestingCount(address)(uint256)" $WALLET --rpc-url $RPC_URL 2>/dev/null || echo "0")
    if [ "$COUNT" = "0" ]; then
        echo "   ⚠️  No vestings to check. Create a vesting first."
    elif [ "$VESTING_ID" -ge "$COUNT" ]; then
        echo "   ⚠️  Vesting ID $VESTING_ID doesn't exist. Max ID is $((COUNT - 1))"
    else
        cast call $VESTING_ADDRESS "vestedAmount(address,uint256)(uint256)" $WALLET $VESTING_ID --rpc-url $RPC_URL
    fi
else
    echo "   cast call $VESTING_ADDRESS \"vestedAmount(address,uint256)(uint256)\" \$WALLET \$VESTING_ID --rpc-url $RPC_URL"
fi
echo ""

echo "3. Get vesting details (struct) - dohvaća pojedinačne vrijednosti:"
if [ -n "$WALLET" ]; then
    COUNT=$(cast call $VESTING_ADDRESS "vestingCount(address)(uint256)" $WALLET --rpc-url $RPC_URL 2>/dev/null || echo "0")
    if [ "$COUNT" = "0" ]; then
        echo "   ⚠️  No vestings to check. Create a vesting first."
    elif [ "$VESTING_ID" -ge "$COUNT" ]; then
        echo "   ⚠️  Vesting ID $VESTING_ID doesn't exist. Max ID is $((COUNT - 1))"
    else
        echo "   Total:"
        cast call $VESTING_ADDRESS "vestings(address,uint256).total(uint128)" $WALLET $VESTING_ID --rpc-url $RPC_URL 2>/dev/null || echo "   Error"
        echo "   Claimed:"
        cast call $VESTING_ADDRESS "vestings(address,uint256).claimed(uint128)" $WALLET $VESTING_ID --rpc-url $RPC_URL 2>/dev/null || echo "   Error"
        echo "   Start:"
        cast call $VESTING_ADDRESS "vestings(address,uint256).start(uint64)" $WALLET $VESTING_ID --rpc-url $RPC_URL 2>/dev/null || echo "   Error"
        echo "   Cliff:"
        cast call $VESTING_ADDRESS "vestings(address,uint256).cliff(uint64)" $WALLET $VESTING_ID --rpc-url $RPC_URL 2>/dev/null || echo "   Error"
        echo "   Duration:"
        cast call $VESTING_ADDRESS "vestings(address,uint256).duration(uint64)" $WALLET $VESTING_ID --rpc-url $RPC_URL 2>/dev/null || echo "   Error"
        echo "   Revoked:"
        cast call $VESTING_ADDRESS "vestings(address,uint256).revoked(bool)" $WALLET $VESTING_ID --rpc-url $RPC_URL 2>/dev/null || echo "   Error"
    fi
else
    echo "   cast call $VESTING_ADDRESS \"vestings(address,uint256).total(uint128)\" \$WALLET \$VESTING_ID --rpc-url $RPC_URL"
    echo "   cast call $VESTING_ADDRESS \"vestings(address,uint256).claimed(uint128)\" \$WALLET \$VESTING_ID --rpc-url $RPC_URL"
    echo "   cast call $VESTING_ADDRESS \"vestings(address,uint256).start(uint64)\" \$WALLET \$VESTING_ID --rpc-url $RPC_URL"
    echo "   cast call $VESTING_ADDRESS \"vestings(address,uint256).cliff(uint64)\" \$WALLET \$VESTING_ID --rpc-url $RPC_URL"
    echo "   cast call $VESTING_ADDRESS \"vestings(address,uint256).duration(uint64)\" \$WALLET \$VESTING_ID --rpc-url $RPC_URL"
    echo "   cast call $VESTING_ADDRESS \"vestings(address,uint256).revoked(bool)\" \$WALLET \$VESTING_ID --rpc-url $RPC_URL"
fi
echo ""

echo "4. Check token address:"
cast call $VESTING_ADDRESS "token()(address)" --rpc-url $RPC_URL
echo ""

# Calculate claimable amount (vested - claimed)
echo "5. Calculate claimable amount (vested - claimed):"
if [ -n "$WALLET" ]; then
    COUNT=$(cast call $VESTING_ADDRESS "vestingCount(address)(uint256)" $WALLET --rpc-url $RPC_URL 2>/dev/null || echo "0")
    if [ "$COUNT" = "0" ]; then
        echo "   ⚠️  No vestings to calculate. Create a vesting first."
    elif [ "$VESTING_ID" -ge "$COUNT" ]; then
        echo "   ⚠️  Vesting ID $VESTING_ID doesn't exist. Max ID is $((COUNT - 1))"
    else
        VESTED=$(cast call $VESTING_ADDRESS "vestedAmount(address,uint256)(uint256)" $WALLET $VESTING_ID --rpc-url $RPC_URL 2>/dev/null || echo "0")
        CLAIMED=$(cast call $VESTING_ADDRESS "vestings(address,uint256).claimed(uint128)" $WALLET $VESTING_ID --rpc-url $RPC_URL 2>/dev/null || echo "0")
        echo "   Vested: $VESTED"
        echo "   Claimed: $CLAIMED"
        if command -v bc &> /dev/null; then
            CLAIMABLE=$(echo "$VESTED - $CLAIMED" | bc)
            echo "   Claimable: $CLAIMABLE"
        else
            echo "   Claimable: $((VESTED - CLAIMED)) (requires bc for large numbers)"
        fi
    fi
else
    echo "   Run with WALLET and VESTING_ID to calculate"
fi
echo ""

# State-changing functions (cast send)
echo "6. Claim vesting (state-changing - needs private key):"
echo "   cast send $VESTING_ADDRESS \"claim(uint256)\" $VESTING_ID --private-key \$PRIVATE_KEY --rpc-url $RPC_URL"
echo ""

echo "7. Create new vesting (admin only):"
echo "   cast send $VESTING_ADDRESS \"createVesting(address,uint256,uint256,uint256,uint256)\" \\"
echo "     \$BENEFICIARY \$TOTAL \$START \$CLIFF_DURATION \$DURATION \\"
echo "     --private-key \$PRIVATE_KEY --rpc-url $RPC_URL"
echo ""

echo "8. Revoke vesting (admin only):"
echo "   cast send $VESTING_ADDRESS \"revoke(address,uint256)\" \$BENEFICIARY \$VESTING_ID \\"
echo "     --private-key \$PRIVATE_KEY --rpc-url $RPC_URL"
echo ""

echo "Note: 'claim()' is a state-changing function, use 'cast send' not 'cast call'"
echo "VESTING_ID starts from 0 (first vesting), 1 (second), etc."

