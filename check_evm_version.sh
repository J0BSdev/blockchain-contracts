#!/bin/bash
# Script za provjeru EVM verzije deployanih kontrakata

set -e

source .env 2>/dev/null || {
    echo "❌ .env file nije pronađen!"
    exit 1
}

if [ -z "$TOKEN_ADDRESS" ] || [ -z "$RPC_URL" ]; then
    echo "❌ TOKEN_ADDRESS ili RPC_URL nisu postavljeni u .env"
    exit 1
fi

echo "🔍 Provjera EVM verzije za kontrakt: $TOKEN_ADDRESS"
echo ""

# Korak 1: Dohvati deployment bytecode s blockchaina
echo "1️⃣ Dohvaćam bytecode s blockchaina..."
DEPLOYED_BYTECODE=$(cast code $TOKEN_ADDRESS --rpc-url $RPC_URL)
echo "$DEPLOYED_BYTECODE" > /tmp/deployed_bytecode.txt
DEPLOYED_SIZE=${#DEPLOYED_BYTECODE}
echo "   ✅ Deployed bytecode size: $DEPLOYED_SIZE bytes"
echo ""

# Korak 2: Build s paris
echo "2️⃣ Buildam lokalno s 'paris' verzijom..."
# Privremeno promijeni foundry.toml
sed -i.bak 's/evm_version = ".*"/evm_version = "paris"/' foundry.toml
forge build --force > /dev/null 2>&1

if [ -f "out/JobsTokenFullV2.sol/JobsTokenFullV2.json" ]; then
    LOCAL_BYTECODE_PARIS=$(cat out/JobsTokenFullV2.sol/JobsTokenFullV2.json | jq -r '.deployedBytecode.object')
    echo "$LOCAL_BYTECODE_PARIS" > /tmp/local_bytecode_paris.txt
    PARIS_SIZE=${#LOCAL_BYTECODE_PARIS}
    echo "   ✅ Local bytecode (paris) size: $PARIS_SIZE bytes"
else
    echo "   ❌ Build nije uspio"
    exit 1
fi
echo ""

# Korak 3: Build s prague
echo "3️⃣ Buildam lokalno s 'prague' verzijom..."
sed -i.bak2 's/evm_version = ".*"/evm_version = "prague"/' foundry.toml
forge build --force > /dev/null 2>&1

if [ -f "out/JobsTokenFullV2.sol/JobsTokenFullV2.json" ]; then
    LOCAL_BYTECODE_PRAGUE=$(cat out/JobsTokenFullV2.sol/JobsTokenFullV2.json | jq -r '.deployedBytecode.object')
    echo "$LOCAL_BYTECODE_PRAGUE" > /tmp/local_bytecode_prague.txt
    PRAGUE_SIZE=${#LOCAL_BYTECODE_PRAGUE}
    echo "   ✅ Local bytecode (prague) size: $PRAGUE_SIZE bytes"
else
    echo "   ❌ Build nije uspio"
    exit 1
fi
echo ""

# Vrati foundry.toml na original
mv foundry.toml.bak foundry.toml 2>/dev/null || true
rm -f foundry.toml.bak2

# Korak 4: Usporedi
echo "4️⃣ Uspoređujem bytecode-e..."
echo ""

# Usporedi s paris
if [ "$DEPLOYED_BYTECODE" = "$LOCAL_BYTECODE_PARIS" ]; then
    echo "✅ REZULTAT: Kontrakt je deployan s 'paris' verzijom!"
    echo ""
    echo "📋 Detalji:"
    echo "   - Deployed bytecode = Local bytecode (paris)"
    echo "   - Size: $DEPLOYED_SIZE bytes"
    exit 0
fi

# Usporedi s prague
if [ "$DEPLOYED_BYTECODE" = "$LOCAL_BYTECODE_PRAGUE" ]; then
    echo "✅ REZULTAT: Kontrakt je deployan s 'prague' verzijom!"
    echo ""
    echo "📋 Detalji:"
    echo "   - Deployed bytecode = Local bytecode (prague)"
    echo "   - Size: $DEPLOYED_SIZE bytes"
    echo ""
    echo "⚠️  UPOZORENJE:"
    echo "   - Kontrakt je deployan s 'prague' (eksperimentalna verzija)"
    echo "   - Etherscan možda ne podržava 'prague'"
    echo "   - Preporuka: Redeploy s 'paris' verzijom"
    exit 0
fi

# Ako se ništa ne podudara
echo "❌ REZULTAT: Bytecode se ne podudara ni s 'paris' ni s 'prague'!"
echo ""
echo "📋 Detalji:"
echo "   - Deployed size: $DEPLOYED_SIZE bytes"
echo "   - Paris size: $PARIS_SIZE bytes"
echo "   - Prague size: $PRAGUE_SIZE bytes"
echo ""
echo "💡 Mogući uzroci:"
echo "   1. Kontrakt je deployan s drugom Solidity verzijom"
echo "   2. Kontrakt je deployan s drugim optimization runs"
echo "   3. Kontrakt je deployan s drugim compiler settings"
echo ""
echo "🔍 Provjeri:"
echo "   - Solidity verzija: $(grep 'solc_version' foundry.toml)"
echo "   - Optimization runs: $(grep 'optimizer_runs' foundry.toml)"
exit 1

