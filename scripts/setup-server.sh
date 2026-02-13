#!/bin/bash
set -e

# Load environment variables
if [ -f .env ]; then
    source .env
else
    echo "Error: .env file not found. Copy .env.example to .env and fill in values."
    exit 1
fi

if [ -z "$HETZNER_IP" ]; then
    echo "Error: HETZNER_IP not set in .env"
    exit 1
fi

# Default to 'moltbot' user, not root (security.md)
SERVER="${HETZNER_USER:-moltbot}@$HETZNER_IP"

echo "=== Setting up Moltbot on $SERVER ==="
echo "Note: This script assumes user has sudo access."
echo "      Run VPS base setup first (see docs/vps-checklist.md §1-4)"
echo ""

# Install Node.js 22 and Moltbot
ssh $SERVER << 'EOF'
set -e

echo "Installing Node.js 22..."
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo bash -
sudo apt-get install -y nodejs

echo "Installing Moltbot..."
sudo npm install -g moltbot

echo "Creating workspace directories..."
mkdir -p ~/clawd/skills
mkdir -p ~/molt/audit
mkdir -p ~/.openclaw

echo ""
echo "Done!"
echo "  Node version: $(node --version)"
echo "  Moltbot version: $(openclaw --version)"
EOF

echo ""
echo "=== Server setup complete ==="
echo ""
echo "Next steps:"
echo "1. Run: ./scripts/deploy.sh (deploy config and prompts)"
echo "2. SSH to server and run:"
echo "   - moltbot auth anthropic --setup-token <your-token>"
echo "   - moltbot channels login telegram"
echo "   - moltbot onboard --install-daemon"
echo ""
echo "See: docs/vps-checklist.md for full checklist"
