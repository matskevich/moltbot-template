#!/usr/bin/env bash
set -euo pipefail

# Connect server git repo to GitHub
# Requires: GitHub repo created (github.com/YOUR_USERNAME/my-bot-memory)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$PROJECT_ROOT/.env"
SERVER="${HETZNER_USER}@${HETZNER_IP}"

echo "Setting up GitHub remote on $SERVER..."
echo ""
echo "Prerequisites:"
echo "  1. Create GitHub repo: https://github.com/new"
echo "     Name: my-bot-memory"
echo "     Visibility: Private"
echo "  2. Copy the repo URL (e.g., git@github.com:YOUR_USERNAME/my-bot-memory.git)"
echo ""

read -p "Enter GitHub repo URL (SSH format): " REPO_URL

if [[ -z "$REPO_URL" ]]; then
  echo "❌ No URL provided"
  exit 1
fi

echo ""
echo "Connecting $SERVER to $REPO_URL..."

ssh $SERVER bash -s << EOF
cd ~/clawd

# Check if git repo exists
if [ ! -d .git ]; then
  echo "❌ Git not initialized. Run ./scripts/setup-git-server.sh first"
  exit 1
fi

# Add remote
git remote add origin "$REPO_URL" 2>/dev/null || git remote set-url origin "$REPO_URL"

# Set branch
git branch -M main

# First push
echo ""
echo "Pushing to GitHub..."
git push -u origin main

echo ""
echo "✅ GitHub remote connected!"
echo "Repo: $REPO_URL"
EOF

echo ""
echo "Done! View your repo:"
echo "  https://github.com/YOUR_USERNAME/my-bot-memory"
