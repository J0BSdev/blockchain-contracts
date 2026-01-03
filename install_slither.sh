#!/bin/bash
# Script za instalaciju Slither-a

echo "🔧 Instalacija Slither-a za security audit..."
echo ""

# Provjeri Python verziju
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 nije instaliran!"
    exit 1
fi

echo "✅ Python3 pronađen: $(python3 --version)"
echo ""

# Opcija 1: Koristi pipx (preporučeno)
if command -v pipx &> /dev/null; then
    echo "📦 Instalacija preko pipx..."
    pipx install slither-analyzer
    echo "✅ Slither instaliran preko pipx!"
    echo ""
    echo "Koristi: pipx run slither ."
    exit 0
fi

# Opcija 2: Instaliraj python3-venv i koristi virtualenv
echo "📦 Instalacija python3-venv paketa..."
echo "Molim te pokreni: sudo apt install python3.12-venv"
echo ""
echo "Zatim pokreni:"
echo "  python3 -m venv venv"
echo "  source venv/bin/activate"
echo "  pip install slither-analyzer"
echo ""

# Opcija 3: Koristi --user flag (najbrže, ali ne preporučeno)
echo "💡 Alternativa: Koristi --user flag (instalira u user directory):"
echo "  pip3 install --user slither-analyzer"
echo ""
echo "Zatim dodaj u PATH:"
echo "  export PATH=\$PATH:\$HOME/.local/bin"
echo ""

# Provjeri je li već instaliran
if command -v slither &> /dev/null; then
    echo "✅ Slither je već instaliran!"
    slither --version
    exit 0
fi

echo "❌ Slither nije instaliran. Koristi jednu od opcija iznad."

