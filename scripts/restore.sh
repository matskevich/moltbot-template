#!/usr/bin/env bash
set -euo pipefail

# Restore бота на сервер из backup
# Восстанавливает WRITABLE файлы (не трогает READ-ONLY)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check args
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <backup-dir>"
  echo ""
  echo "Available backups:"
  ls -1d "$PROJECT_ROOT/backups"/*/ 2>/dev/null | xargs -n1 basename || echo "  (none)"
  exit 1
fi

BACKUP_NAME="$1"
BACKUP_DIR="$PROJECT_ROOT/backups/$BACKUP_NAME"

if [[ ! -d "$BACKUP_DIR" ]]; then
  echo "❌ Backup not found: $BACKUP_DIR"
  exit 1
fi

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

echo "⚠️  WARNING: This will overwrite bot's WRITABLE files on $SERVER"
echo "📂 Backup source: $BACKUP_DIR"
echo ""
read -p "Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "❌ Aborted"
  exit 1
fi

echo ""
echo "🔄 Restoring to $SERVER..."

# Restore WRITABLE files
echo "📤 Uploading WRITABLE files..."

# SOUL.md, USER.md
[[ -f "$BACKUP_DIR/SOUL.md" ]] && rsync -avz --progress "$BACKUP_DIR/SOUL.md" "$SERVER:~/clawd/"
[[ -f "$BACKUP_DIR/USER.md" ]] && rsync -avz --progress "$BACKUP_DIR/USER.md" "$SERVER:~/clawd/"

# skills/
[[ -d "$BACKUP_DIR/skills" ]] && rsync -avz --progress "$BACKUP_DIR/skills/" "$SERVER:~/clawd/skills/"

# custom/
[[ -d "$BACKUP_DIR/custom" ]] && rsync -avz --progress "$BACKUP_DIR/custom/" "$SERVER:~/clawd/custom/"

# meta/
[[ -d "$BACKUP_DIR/meta" ]] && rsync -avz --progress "$BACKUP_DIR/meta/" "$SERVER:~/clawd/meta/"

# memory/
[[ -d "$BACKUP_DIR/memory" ]] && rsync -avz --progress "$BACKUP_DIR/memory/" "$SERVER:~/clawd/memory/"

echo ""
echo "✅ Restore complete!"
echo ""
echo "Next steps:"
echo "1. SSH to server: ssh $SERVER"
echo "2. Restart moltbot: sudo systemctl restart moltbot"
echo "3. Check logs: journalctl -u moltbot -f"
echo "4. Test in Telegram: /reset"
