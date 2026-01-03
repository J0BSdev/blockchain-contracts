#!/bin/bash
# Helper script za pokretanje Slither security audit-a

export PATH=$PATH:$HOME/.local/bin

echo "🔒 Slither Security Audit"
echo "=========================="
echo ""

# Provjeri je li Slither instaliran
if ! command -v slither &> /dev/null; then
    echo "❌ Slither nije instaliran!"
    echo "Instaliraj sa: pip3 install --user --break-system-packages slither-analyzer"
    exit 1
fi

echo "✅ Slither verzija: $(slither --version)"
echo ""

# Opcije
case "${1:-all}" in
    staking)
        echo "📊 Analiziranje JobsTokenStaking..."
        slither src/tokens/staking/JobsTokenStaking.sol --print human-summary
        ;;
    vesting)
        echo "📊 Analiziranje JobsTokenVestingERC20..."
        slither src/tokens/vesting/JobsTokenVestingERC20.sol --print human-summary
        ;;
    token)
        echo "📊 Analiziranje JobsTokenFullV2..."
        slither src/tokens/erc20/JobsTokenFullV2.sol --print human-summary
        ;;
    all|*)
        echo "📊 Analiziranje svih kontrakata..."
        slither . --exclude-dependencies --exclude-optimization --print human-summary
        ;;
esac

echo ""
echo "✅ Analiza završena!"
echo ""
echo "💡 Za detaljniju analizu:"
echo "   slither . --print human-summary"
echo "   slither . --json slither-report.json"

