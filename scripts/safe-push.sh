#!/usr/bin/env bash
set -euo pipefail

# Safe Push: ensures we don't overwrite bot's uncommitted work
#
# Flow:
# 1. Ask server to commit & push all bot's changes
# 2. Pull latest from server to local
# 3. Show diff of what we're about to push
# 4. Ask confirmation
# 5. Push our changes
#
# Usage:
#   ./scripts/safe-push.sh              # Interactive safe push
#   ./scripts/safe-push.sh --force      # Skip confirmations (CI/automation)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$PROJECT_ROOT/.env"
SERVER="${HETZNER_USER}@${HETZNER_IP}"

FORCE="${1:-}"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    SAFE PUSH WORKFLOW                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================
# STEP 1: Force bot to commit everything
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 1: Saving bot's work on server..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Run auto-commit on server
ssh "$SERVER" 'cd ~/clawd &&
  # Backup config first
  mkdir -p config-backup
  cp ~/.openclaw/openclaw.json config-backup/openclaw.json 2>/dev/null || true

  # Check for changes
  if git diff-index --quiet HEAD -- && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    echo "✓ No uncommitted changes on server"
  else
    echo "📦 Committing bot'"'"'s changes..."
    git add -A
    git commit -m "Pre-sync backup: $(date +%Y-%m-%d\ %H:%M)" || true
    git push origin main || echo "⚠️  Push failed (will retry)"
    echo "✓ Bot'"'"'s changes saved to GitHub"
  fi
'

echo ""

# ============================================================
# STEP 2: Pull latest from server
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 2: Pulling latest bot's work..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Create directories if needed
mkdir -p "$PROJECT_ROOT/prompts"
mkdir -p "$PROJECT_ROOT/skills-server"
mkdir -p "$PROJECT_ROOT/custom"
mkdir -p "$PROJECT_ROOT/meta"
mkdir -p "$PROJECT_ROOT/config"

# Pull bot-owned files
rsync -avz --progress "$SERVER:~/clawd/SOUL.md" "$PROJECT_ROOT/prompts/" 2>/dev/null || echo "  (SOUL.md not found)"
rsync -avz --progress "$SERVER:~/clawd/USER.md" "$PROJECT_ROOT/prompts/" 2>/dev/null || echo "  (USER.md not found)"
rsync -avz --progress --exclude 'venv/' --exclude '.venv/' --exclude 'node_modules/' \
  "$SERVER:~/clawd/skills/" "$PROJECT_ROOT/skills-server/" 2>/dev/null || echo "  (skills/ not found)"
rsync -avz --progress "$SERVER:~/clawd/custom/" "$PROJECT_ROOT/custom/" 2>/dev/null || echo "  (custom/ not found)"
rsync -avz --progress "$SERVER:~/clawd/meta/" "$PROJECT_ROOT/meta/" 2>/dev/null || echo "  (meta/ not found)"
rsync -avz --progress "$SERVER:~/.openclaw/openclaw.json" "$PROJECT_ROOT/config/openclaw-server.json" 2>/dev/null || echo "  (config not found)"

echo ""
echo "✓ Pull complete"
echo ""

# ============================================================
# STEP 3: Show what changed locally (bot's work we just pulled)
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 3: Changes from bot (just pulled):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cd "$PROJECT_ROOT"
if git diff --stat HEAD 2>/dev/null | head -20; then
  :
else
  echo "  (no changes)"
fi

# Show untracked
UNTRACKED=$(git ls-files --others --exclude-standard | head -10)
if [ -n "$UNTRACKED" ]; then
  echo ""
  echo "New files from bot:"
  echo "$UNTRACKED"
fi

echo ""

# ============================================================
# STEP 4: Commit pulled changes locally
# ============================================================
if ! git diff-index --quiet HEAD -- || [ -n "$(git ls-files --others --exclude-standard)" ]; then
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "STEP 4: Committing bot's changes locally..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  git add -A
  git commit -m "Sync: pulled bot's changes $(date +%Y-%m-%d)" || echo "  (nothing to commit)"
  echo ""
fi

# ============================================================
# STEP 5: Show what WE are about to push to server
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 5: What will be pushed to server:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Compare local prompts/AGENTS.md with server
echo ""
echo "📝 AGENTS.md diff:"
TEMP_DIR=$(mktemp -d)
rsync -az "$SERVER:~/clawd/AGENTS.md" "$TEMP_DIR/AGENTS.md.server" 2>/dev/null || touch "$TEMP_DIR/AGENTS.md.server"
if ! diff -q "$PROJECT_ROOT/prompts/AGENTS.md" "$TEMP_DIR/AGENTS.md.server" > /dev/null 2>&1; then
  diff -u "$TEMP_DIR/AGENTS.md.server" "$PROJECT_ROOT/prompts/AGENTS.md" | head -30 || true
else
  echo "  (no changes)"
fi
rm -rf "$TEMP_DIR"

echo ""
echo "📝 SECURITY.md diff:"
TEMP_DIR=$(mktemp -d)
rsync -az "$SERVER:~/clawd/SECURITY.md" "$TEMP_DIR/SECURITY.md.server" 2>/dev/null || touch "$TEMP_DIR/SECURITY.md.server"
if ! diff -q "$PROJECT_ROOT/prompts/SECURITY.md" "$TEMP_DIR/SECURITY.md.server" > /dev/null 2>&1; then
  diff -u "$TEMP_DIR/SECURITY.md.server" "$PROJECT_ROOT/prompts/SECURITY.md" | head -30 || true
else
  echo "  (no changes)"
fi
rm -rf "$TEMP_DIR"

echo ""

# ============================================================
# STEP 6: Confirm and push
# ============================================================
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "STEP 6: Push to server"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Will deploy to server:"
echo "  • AGENTS.md (overwrite)"
echo "  • SECURITY.md (overwrite)"
echo "  • skills/ (new files only, --ignore-existing)"
echo ""

if [[ "$FORCE" != "--force" ]]; then
  read -p "Continue with push? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Aborted"
    exit 1
  fi
fi

echo ""
echo "📤 Pushing to server..."

# Push READ-ONLY files (we own these)
rsync -avz --progress "$PROJECT_ROOT/prompts/AGENTS.md" "$SERVER:~/clawd/AGENTS.md"
rsync -avz --progress "$PROJECT_ROOT/prompts/SECURITY.md" "$SERVER:~/clawd/SECURITY.md"

# Seed skills (new only, don't overwrite bot's changes)
rsync -avz --progress --ignore-existing "$PROJECT_ROOT/skills/" "$SERVER:~/clawd/skills/" 2>/dev/null || true

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    ✅ SAFE PUSH COMPLETE                       ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Don't forget to:"
echo "  1. git push  (push to GitHub)"
echo "  2. Optionally restart bot: ssh $SERVER 'systemctl --user restart moltbot'"
echo ""
