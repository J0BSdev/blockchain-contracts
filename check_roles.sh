#!/bin/bash
# Script to check AccessControl roles on JobsTokenFullV2

TOKEN_ADDRESS=${TOKEN_ADDRESS:-""}
RPC_URL=${RPC_URL:-""}
ADDRESS_TO_CHECK=${ADDRESS_TO_CHECK:-""}

if [ -z "$TOKEN_ADDRESS" ] || [ -z "$RPC_URL" ]; then
    echo "Usage: TOKEN_ADDRESS=0x... RPC_URL=... [ADDRESS_TO_CHECK=0x...] ./check_roles.sh"
    exit 1
fi

echo "Checking roles on token: $TOKEN_ADDRESS"
echo ""

# Role constants
DEFAULT_ADMIN_ROLE="0x0000000000000000000000000000000000000000000000000000000000000000"
MINTER_ROLE=$(cast keccak "MINTER_ROLE")
PAUSER_ROLE=$(cast keccak "PAUSER_ROLE")

echo "Role hashes:"
echo "DEFAULT_ADMIN_ROLE: $DEFAULT_ADMIN_ROLE"
echo "MINTER_ROLE: $MINTER_ROLE"
echo "PAUSER_ROLE: $PAUSER_ROLE"
echo ""

# Check if address has roles (if provided)
if [ -n "$ADDRESS_TO_CHECK" ]; then
    echo "Checking roles for: $ADDRESS_TO_CHECK"
    echo ""
    
    echo "DEFAULT_ADMIN_ROLE:"
    cast call $TOKEN_ADDRESS "hasRole(bytes32,address)(bool)" $DEFAULT_ADMIN_ROLE $ADDRESS_TO_CHECK --rpc-url $RPC_URL
    
    echo "MINTER_ROLE:"
    cast call $TOKEN_ADDRESS "hasRole(bytes32,address)(bool)" $MINTER_ROLE $ADDRESS_TO_CHECK --rpc-url $RPC_URL
    
    echo "PAUSER_ROLE:"
    cast call $TOKEN_ADDRESS "hasRole(bytes32,address)(bool)" $PAUSER_ROLE $ADDRESS_TO_CHECK --rpc-url $RPC_URL
else
    echo "To check if an address has a role, use:"
    echo "  cast call $TOKEN_ADDRESS \"hasRole(bytes32,address)(bool)\" \$ROLE \$ADDRESS --rpc-url $RPC_URL"
    echo ""
    echo "Example:"
    echo "  cast call $TOKEN_ADDRESS \"hasRole(bytes32,address)(bool)\" $DEFAULT_ADMIN_ROLE 0xYourAddress --rpc-url $RPC_URL"
fi

echo ""
echo "Note: AccessControl (not AccessControlEnumerable) doesn't support getRoleMember()."
echo "You can only check if a specific address has a role using hasRole()."

