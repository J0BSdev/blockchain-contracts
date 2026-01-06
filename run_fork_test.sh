#!/bin/bash

# Fork Test Runner
# Testira kontrakte na forkovanom blockchainu

set -e

# Učitaj .env ako postoji
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Provjeri RPC URL
FORK_URL=${FORK_URL:-${RPC_URL:-""}}

if [ -z "$FORK_URL" ]; then
    echo "❌ FORK_URL ili RPC_URL nisu postavljeni!"
    echo ""
    echo "Postavi RPC URL:"
    echo "  export FORK_URL=https://sepolia.infura.io/v3/YOUR_KEY"
    echo "  # ili"
    echo "  export FORK_URL=\$RPC_URL"
    echo ""
    echo "Zatim pokreni:"
    echo "  ./run_fork_test.sh"
    exit 1
fi

echo "🔗 Fork URL: $FORK_URL"
echo ""
echo "🧪 Pokretanje fork testova..."
echo ""

# Pokreni fork testove
forge test \
    --match-contract Fork \
    --fork-url "$FORK_URL" \
    -vv

echo ""
echo "✅ Fork testovi završeni!"

