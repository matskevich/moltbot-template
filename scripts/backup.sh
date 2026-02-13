#!/usr/bin/env bash
set -euo pipefail

# Backup бота с сервера
# Скачивает все WRITABLE файлы (memory, code, learnings) локально

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Load .env
if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
  echo "❌ .env not found. Copy .env.example and fill it."
  exit 1
fi
source "$PROJECT_ROOT/.env"

# Check required vars
if [[ -z "${HETZNER_IP:-}" ]] || [[ -z "${HETZNER_USER:-}" ]]; then
  echo "❌ HETZNER_IP and HETZNER_USER must be set in .env"
  exit 1
fi

SERVER="${HETZNER_USER}@${HETZNER_IP}"
BACKUP_DIR="$PROJECT_ROOT/backups/$(date +%Y-%m-%d_%H%M%S)"

echo "🔄 Backing up from $SERVER"
echo "📦 Backup destination: $BACKUP_DIR"

# Create backup dir
mkdir -p "$BACKUP_DIR"

# Backup critical files
echo ""
echo "📥 Downloading WRITABLE files (bot's memory & code)..."

# SOUL.md, USER.md
rsync -avz --progress "$SERVER:~/clawd/SOUL.md" "$BACKUP_DIR/" 2>/dev/null || echo "⚠️  SOUL.md not found (skip)"
rsync -avz --progress "$SERVER:~/clawd/USER.md" "$BACKUP_DIR/" 2>/dev/null || echo "⚠️  USER.md not found (skip)"

# skills/
rsync -avz --progress "$SERVER:~/clawd/skills/" "$BACKUP_DIR/skills/" 2>/dev/null || echo "⚠️  skills/ not found (skip)"

# custom/
rsync -avz --progress "$SERVER:~/clawd/custom/" "$BACKUP_DIR/custom/" 2>/dev/null || echo "⚠️  custom/ not found (skip)"

# meta/
rsync -avz --progress "$SERVER:~/clawd/meta/" "$BACKUP_DIR/meta/" 2>/dev/null || echo "⚠️  meta/ not found (skip)"

# memory/
rsync -avz --progress "$SERVER:~/clawd/memory/" "$BACKUP_DIR/memory/" 2>/dev/null || echo "⚠️  memory/ not found (skip)"

# Config (for reference)
rsync -avz --progress "$SERVER:~/.openclaw/openclaw.json" "$BACKUP_DIR/moltbot.json" 2>/dev/null || echo "⚠️  moltbot.json not found (skip)"

echo ""
echo "✅ Backup complete!"
echo "📂 Location: $BACKUP_DIR"
echo ""
echo "Contents:"
ls -lh "$BACKUP_DIR"

echo ""
echo "💡 To restore: ./scripts/restore.sh $(basename "$BACKUP_DIR")"
