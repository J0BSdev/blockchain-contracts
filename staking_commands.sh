#!/bin/bash
# Helper commands for JobsTokenStaking

STAKING_ADDRESS=${STAKING_ADDRESS:-""}
RPC_URL=${RPC_URL:-""}
WALLET=${WALLET:-""}

if [ -z "$STAKING_ADDRESS" ] || [ -z "$RPC_URL" ]; then
    echo "Usage: STAKING_ADDRESS=0x... RPC_URL=... [WALLET=0x...] ./staking_commands.sh"
    exit 1
fi

echo "=== JobsTokenStaking Commands ==="
echo ""

# View functions (cast call)
echo "1. Check pending rewards (view):"
if [ -n "$WALLET" ]; then
    cast call $STAKING_ADDRESS "pendingRewards(address)(uint256)" $WALLET --rpc-url $RPC_URL
else
    echo "   cast call $STAKING_ADDRESS \"pendingRewards(address)(uint256)\" \$WALLET --rpc-url $RPC_URL"
fi
echo ""

echo "2. Check user staked balance:"
if [ -n "$WALLET" ]; then
    cast call $STAKING_ADDRESS "balanceOf(address)(uint256)" $WALLET --rpc-url $RPC_URL
else
    echo "   cast call $STAKING_ADDRESS \"balanceOf(address)(uint256)\" \$WALLET --rpc-url $RPC_URL"
fi
echo ""

echo "3. Check total staked:"
cast call $STAKING_ADDRESS "totalStaked()(uint256)" --rpc-url $RPC_URL
echo ""

echo "4. Check reward rate per second:"
cast call $STAKING_ADDRESS "rewardRatePerSecond()(uint256)" --rpc-url $RPC_URL
echo ""

# State-changing functions (cast send)
echo "5. Claim rewards (state-changing - needs private key):"
echo "   cast send $STAKING_ADDRESS \"claim()\" --private-key \$PRIVATE_KEY --rpc-url $RPC_URL"
echo ""

echo "6. Stake tokens:"
echo "   cast send $STAKING_ADDRESS \"stake(uint256)\" \$AMOUNT --private-key \$PRIVATE_KEY --rpc-url $RPC_URL"
echo ""

echo "7. Unstake tokens:"
echo "   cast send $STAKING_ADDRESS \"unstake(uint256)\" \$AMOUNT --private-key \$PRIVATE_KEY --rpc-url $RPC_URL"
echo ""

echo "Note: 'claim()' is a state-changing function, use 'cast send' not 'cast call'"

