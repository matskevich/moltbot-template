#!/bin/bash
# Install pre-commit hooks for secret detection
# Run this after cloning the repo

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Installing pre-commit hooks..."

# Install local hook
if [ -d "$PROJECT_ROOT/.git" ]; then
  cat > "$PROJECT_ROOT/.git/hooks/pre-commit" << 'EOF'
#!/bin/bash
exec ./scripts/check-secrets.sh
EOF
  chmod +x "$PROJECT_ROOT/.git/hooks/pre-commit"
  echo "✓ Installed pre-commit hook"
else
  echo "⚠️  No .git directory found - skip local hook"
fi

# Install server hook if .env exists
if [ -f "$PROJECT_ROOT/.env" ]; then
  source "$PROJECT_ROOT/.env"
  if [ -n "$HETZNER_IP" ] && [ -n "$HETZNER_USER" ]; then
    echo "Installing hook on server..."
    ssh "$HETZNER_USER@$HETZNER_IP" 'cd ~/clawd && mkdir -p scripts && cat > scripts/check-secrets.sh << '\''INNEREOF'\''
#!/bin/bash
set -e
FILES="${@:-$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null)}"
FOUND=0
PATTERNS="sk-ant-[a-zA-Z0-9_-]{20,}
sk-proj-[a-zA-Z0-9_-]{20,}
gsk_[a-zA-Z0-9]{50,}
AIzaSy[a-zA-Z0-9_-]{33}
[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}
[0-9]{10}:[A-Za-z0-9_-]{35}"
for file in $FILES; do
  [ ! -f "$file" ] && continue
  case "$file" in *.env.example|*check-secrets.sh|*SECURITY.md|*.gitignore) continue ;; esac
  for pattern in $PATTERNS; do
    if grep -qE "$pattern" "$file" 2>/dev/null; then
      echo "⚠️  Possible secret in $file"
      grep -nE "$pattern" "$file" | head -2
      FOUND=1
    fi
  done
done
[ $FOUND -eq 1 ] && echo "❌ Secrets detected!" && exit 1
echo "✓ No secrets detected"
INNEREOF
chmod +x scripts/check-secrets.sh
cat > .git/hooks/pre-commit << '\''HOOKEOF'\''
#!/bin/bash
exec ./scripts/check-secrets.sh
HOOKEOF
chmod +x .git/hooks/pre-commit
echo "✓ Installed"'
    echo "✓ Installed pre-commit hook on server"
  fi
else
  echo "⚠️  No .env file - skip server hook (run after setup)"
fi

echo ""
echo "Done! Pre-commit hooks will block commits with secrets."
echo ""
echo "Test with: ./scripts/check-secrets.sh"
