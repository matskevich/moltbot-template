#!/usr/bin/env bash
set -euo pipefail

# Setup git repo on server
# One-time setup for bot memory versioning

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$PROJECT_ROOT/.env"
SERVER="${HETZNER_USER}@${HETZNER_IP}"

echo "Setting up git repo on $SERVER..."

ssh $SERVER 'bash -s' << 'EOF'
cd ~/clawd

# Init git if not exists
if [ ! -d .git ]; then
  git init
  git config user.name "Moltbot"
  git config user.email "bot@moltbot.local"
fi

# .gitignore
cat > .gitignore << 'IGNORE'
# Never commit these
.env
*.log
*.tmp

# Bot's runtime (not in git)
.prose/
node_modules/
venv/
__pycache__/

# Skills venv (heavy)
skills/*/venv/
skills/*/.venv/
skills/*/node_modules/
IGNORE

# Initial commit
git add .
git commit -m "Initial: bot memory and code" || echo "Already committed"

echo "✅ Git initialized in ~/clawd"
EOF

echo ""
echo "Next step: add GitHub remote (optional)"
echo "  1. Create private repo: github.com/YOUR_USERNAME/my-bot-memory"
echo "  2. On server: cd ~/clawd && git remote add origin git@github.com:..."
echo "  3. Push: git push -u origin main"
