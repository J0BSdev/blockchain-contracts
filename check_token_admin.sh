#!/bin/bash
# Script to check token admin/owner

TOKEN_ADDRESS=${TOKEN_ADDRESS:-""}
RPC_URL=${RPC_URL:-""}
ADMIN_ADDRESS=${ADMIN_ADDRESS:-""}

if [ -z "$TOKEN_ADDRESS" ] || [ -z "$RPC_URL" ]; then
    echo "Usage: TOKEN_ADDRESS=0x... RPC_URL=... [ADMIN_ADDRESS=0x...] ./check_token_admin.sh"
    exit 1
fi

echo "Checking token at: $TOKEN_ADDRESS"
echo ""

# Try to get name to identify contract type
echo "Token name:"
cast call $TOKEN_ADDRESS "name()(string)" --rpc-url $RPC_URL 2>/dev/null || echo "Could not get name"
echo ""

# Try owner() - works for JobsTokenFull (Ownable)
echo "Checking owner() (JobsTokenFull):"
cast call $TOKEN_ADDRESS "owner()(address)" --rpc-url $RPC_URL 2>/dev/null && echo "✓ Has owner() - this is JobsTokenFull" || echo "✗ No owner() - likely JobsTokenFullV2"
echo ""

# Check AccessControl - works for JobsTokenFullV2
if [ -n "$ADMIN_ADDRESS" ]; then
    echo "Checking AccessControl admin (JobsTokenFullV2):"
    DEFAULT_ADMIN_ROLE="0x0000000000000000000000000000000000000000000000000000000000000000"
    cast call $TOKEN_ADDRESS "hasRole(bytes32,address)(bool)" $DEFAULT_ADMIN_ROLE $ADMIN_ADDRESS --rpc-url $RPC_URL 2>/dev/null && echo "✓ $ADMIN_ADDRESS has DEFAULT_ADMIN_ROLE" || echo "✗ $ADMIN_ADDRESS does not have DEFAULT_ADMIN_ROLE"
    echo ""
fi

# List all roles (if AccessControl)
echo "Available roles:"
echo "DEFAULT_ADMIN_ROLE: 0x0000000000000000000000000000000000000000000000000000000000000000"
cast call $TOKEN_ADDRESS "MINTER_ROLE()(bytes32)" --rpc-url $RPC_URL 2>/dev/null && echo "MINTER_ROLE found" || echo ""
cast call $TOKEN_ADDRESS "PAUSER_ROLE()(bytes32)" --rpc-url $RPC_URL 2>/dev/null && echo "PAUSER_ROLE found" || echo ""

