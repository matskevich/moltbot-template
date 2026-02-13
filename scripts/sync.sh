#!/usr/bin/env bash
set -euo pipefail

# Two-way sync between local and server
# Usage:
#   ./scripts/sync.sh pull                    # Download bot's changes
#   ./scripts/sync.sh push                    # Upload READ-ONLY files (safe)
#   ./scripts/sync.sh push --all              # Upload ALL files (override bot)
#   ./scripts/sync.sh push prompts/SOUL.md    # Upload specific file

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

source "$PROJECT_ROOT/.env"
SERVER="${HETZNER_USER}@${HETZNER_IP}"

COMMAND="${1:-}"
MODE="${2:-readonly}"  # readonly | all | <file>

if [[ "$COMMAND" != "pull" && "$COMMAND" != "push" ]]; then
  echo "Usage: $0 {pull|push} [options]"
  echo ""
  echo "  pull                     - Download bot's changes from server"
  echo "  push                     - Upload READ-ONLY files (AGENTS.md, SECURITY.md)"
  echo "  push --all               - Upload ALL files (⚠️  overwrites bot's work)"
  echo "  push <file>              - Upload specific file (e.g., prompts/SOUL.md)"
  echo ""
  echo "Examples:"
  echo "  $0 pull"
  echo "  $0 push"
  echo "  $0 push --all"
  echo "  $0 push prompts/SOUL.md"
  exit 1
fi

#
# PULL: Download bot's changes
#
if [[ "$COMMAND" == "pull" ]]; then
  echo "🔄 Pulling bot's changes from $SERVER..."
  echo ""

  # BOT OWNS files - download from server
  echo "📥 Downloading BOT OWNS files..."

  # SOUL.md, USER.md
  rsync -avz --progress "$SERVER:~/clawd/SOUL.md" "$PROJECT_ROOT/prompts/" || echo "⚠️  SOUL.md not found"
  rsync -avz --progress "$SERVER:~/clawd/USER.md" "$PROJECT_ROOT/prompts/" || echo "⚠️  USER.md not found"

  # skills/ (all bot's skills)
  rsync -avz --progress --exclude 'venv/' --exclude '.venv/' --exclude 'node_modules/' \
    "$SERVER:~/clawd/skills/" "$PROJECT_ROOT/skills-server/" || echo "⚠️  skills/ not found"

  # custom/, meta/
  rsync -avz --progress "$SERVER:~/clawd/custom/" "$PROJECT_ROOT/custom/" || echo "⚠️  custom/ not found"
  rsync -avz --progress "$SERVER:~/clawd/meta/" "$PROJECT_ROOT/meta/" || echo "⚠️  meta/ not found"

  # Config (for reference, DON'T deploy back)
  rsync -avz --progress "$SERVER:~/.openclaw/openclaw.json" "$PROJECT_ROOT/config/openclaw-server.json" || echo "⚠️  config not found"

  echo ""
  echo "✅ Pull complete!"
  echo ""
  echo "Bot's changes downloaded to:"
  echo "  - prompts/SOUL.md, USER.md"
  echo "  - skills-server/"
  echo "  - custom/, meta/"
  echo "  - config/openclaw-server.json (reference)"
  echo ""
  echo "Review changes, commit to git if needed."
fi

#
# PUSH: Upload our changes
#
if [[ "$COMMAND" == "push" ]]; then

  # Specific file mode
  if [[ "$MODE" != "readonly" && "$MODE" != "--all" ]]; then
    FILE="$MODE"
    if [[ ! -f "$PROJECT_ROOT/$FILE" ]]; then
      echo "❌ File not found: $FILE"
      exit 1
    fi

    # Determine target path
    TARGET=""
    if [[ "$FILE" == prompts/* ]]; then
      TARGET="~/clawd/$(basename $FILE)"
    elif [[ "$FILE" == skills/* ]]; then
      TARGET="~/clawd/$FILE"
    elif [[ "$FILE" == custom/* ]] || [[ "$FILE" == meta/* ]]; then
      TARGET="~/clawd/$FILE"
    else
      echo "❌ Unknown file type: $FILE"
      echo "Supported: prompts/*, skills/*, custom/*, meta/*"
      exit 1
    fi

    echo "⚠️  WARNING: Uploading BOT OWNS file!"
    echo ""
    echo "  Local:  $FILE"
    echo "  Server: $TARGET"
    echo ""
    echo "This will OVERWRITE bot's changes on the server."
    read -p "Continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "❌ Aborted"
      exit 1
    fi

    rsync -avz --progress "$PROJECT_ROOT/$FILE" "$SERVER:$TARGET"
    echo ""
    echo "✅ Uploaded: $FILE"
    exit 0
  fi

  # --all mode
  if [[ "$MODE" == "--all" ]]; then
    echo "🔥 WARNING: PUSH --all mode"
    echo ""
    echo "This will upload ALL files, including BOT OWNS:"
    echo "  - SOUL.md, USER.md (bot's personality & memory)"
    echo "  - skills/ (ALL skills, overwrite bot's)"
    echo "  - custom/, meta/ (bot's notes)"
    echo ""
    echo "⚠️  Bot's work will be OVERWRITTEN!"
    echo ""
    read -p "Are you SURE? [yes/N] " -r
    echo
    if [[ "$REPLY" != "yes" ]]; then
      echo "❌ Aborted (type 'yes' to confirm)"
      exit 1
    fi

    echo ""
    echo "📤 Uploading ALL files..."

    # READ-ONLY
    rsync -avz --progress "$PROJECT_ROOT/prompts/AGENTS.md" "$SERVER:~/clawd/AGENTS.md"
    rsync -avz --progress "$PROJECT_ROOT/prompts/SECURITY.md" "$SERVER:~/clawd/SECURITY.md"

    # BOT OWNS (OVERWRITE!)
    rsync -avz --progress "$PROJECT_ROOT/prompts/SOUL.md" "$SERVER:~/clawd/SOUL.md" 2>/dev/null || echo "⚠️  SOUL.md not found locally"
    rsync -avz --progress "$PROJECT_ROOT/prompts/USER.md" "$SERVER:~/clawd/USER.md" 2>/dev/null || echo "⚠️  USER.md not found locally"

    rsync -avz --progress --exclude 'venv/' --exclude '.venv/' --exclude 'node_modules/' \
      "$PROJECT_ROOT/skills/" "$SERVER:~/clawd/skills/" 2>/dev/null || echo "⚠️  skills/ not found"

    rsync -avz --progress "$PROJECT_ROOT/custom/" "$SERVER:~/clawd/custom/" 2>/dev/null || echo "⚠️  custom/ not found"
    rsync -avz --progress "$PROJECT_ROOT/meta/" "$SERVER:~/clawd/meta/" 2>/dev/null || echo "⚠️  meta/ not found"

    echo ""
    echo "✅ All files uploaded!"
    echo ""
    echo "Restart moltbot:"
    echo "  ssh $SERVER 'systemctl --user restart moltbot'"
    exit 0
  fi

  # Default: READ-ONLY mode
  echo "📤 PUSH: Uploading READ-ONLY files (safe)"
  echo ""

  # Safety check: show diff
  echo "Checking changes..."
  TEMP_DIR=$(mktemp -d)
  rsync -az "$SERVER:~/clawd/AGENTS.md" "$TEMP_DIR/AGENTS.md.server" 2>/dev/null || touch "$TEMP_DIR/AGENTS.md.server"

  if ! diff -q "$PROJECT_ROOT/prompts/AGENTS.md" "$TEMP_DIR/AGENTS.md.server" > /dev/null 2>&1; then
    echo "📝 AGENTS.md changes:"
    diff -u "$TEMP_DIR/AGENTS.md.server" "$PROJECT_ROOT/prompts/AGENTS.md" | head -30 || true
    echo ""
  fi
  rm -rf "$TEMP_DIR"

  # Confirm
  read -p "Deploy AGENTS.md and SECURITY.md? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Aborted"
    exit 1
  fi

  echo ""
  echo "📤 Deploying..."

  # AGENTS.md, SECURITY.md (we own)
  rsync -avz --progress "$PROJECT_ROOT/prompts/AGENTS.md" "$SERVER:~/clawd/AGENTS.md"
  rsync -avz --progress "$PROJECT_ROOT/prompts/SECURITY.md" "$SERVER:~/clawd/SECURITY.md"

  # Seed skills (new only)
  rsync -avz --progress --ignore-existing "$PROJECT_ROOT/skills/" "$SERVER:~/clawd/skills/"

  echo ""
  echo "✅ Push complete!"
  echo ""
  echo "Deployed:"
  echo "  - AGENTS.md, SECURITY.md (overwrite)"
  echo "  - skills/ (new files only)"
  echo ""
  echo "Restart: ssh $SERVER 'systemctl --user restart moltbot'"
fi
