#!/bin/bash
# Pre-commit hook: blocks secrets AND PII in staged files
# Install: cp scripts/pre-commit-secrets-check.sh .git/hooks/pre-commit && chmod +x .git/hooks/pre-commit
#
# For public repos (openclaw-infra, openclaw-brain, arena-hub):
#   blocks API keys, bot tokens, server IPs, telegram IDs, real names
#
# Override: git commit --no-verify (private repos only)

set -e

RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "🔍 Checking staged files for secrets and PII..."

# ── SECRETS ──────────────────────────────────────────────
SECRET_PATTERNS=(
    'sk-ant-[a-zA-Z0-9_-]{20,}'          # Anthropic API key
    'sk-proj-[a-zA-Z0-9_-]{20,}'         # OpenAI API key
    'sk-[a-zA-Z0-9]{48}'                  # OpenAI old format
    'gsk_[a-zA-Z0-9]{50,}'               # Groq API key
    'AIzaSy[a-zA-Z0-9_-]{33}'            # Google/Gemini API key
    'ghp_[a-zA-Z0-9]{36}'                # GitHub PAT
    'PRIVATE KEY-----'                     # SSH/SSL private keys
    '[0-9]{10}:[A-Za-z0-9_-]{35}'         # Telegram bot token
    '\b[0-9a-f]{64}\b'                     # 256-bit hex (gateway tokens)
    'HETZNER_API_TOKEN=[A-Za-z0-9]{64}'   # Hetzner API (env assignment)
)

# ── PII: customize per project ──────────────────────────
# Add your real data patterns here. Examples below.
PII_PATTERNS=(
    # Telegram numeric IDs (7+ digit user/group IDs in non-URL context)
    # Add specific IDs you want to block:
    # '[0-9]{7,10}'   # too broad — use specific IDs instead
    # '@your_username'
    # 'YourRealName'
    # 'your\.server\.ip'
)

# ── PII config file (optional, one pattern per line) ─────
PII_CONFIG=".pii-patterns"
if [ -f "$PII_CONFIG" ]; then
    while IFS= read -r line; do
        [[ -z "$line" || "$line" == \#* ]] && continue
        PII_PATTERNS+=("$line")
    done < "$PII_CONFIG"
fi

# ── Files to skip ────────────────────────────────────────
SKIP_PATTERNS=(
    '\.env\.example$'
    'check-secrets\.sh$'
    'pre-commit-secrets-check\.sh$'
    'SECURITY\.md$'
    '\.gitignore$'
    '\.pii-patterns$'
    'audit-.*\.md$'
    '\.png$|\.jpg$|\.jpeg$|\.gif$|\.zip$|\.tar$'
)

# ── Run checks ───────────────────────────────────────────
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || true)
[ -z "$STAGED_FILES" ] && echo -e "${GREEN}✓ No staged files${NC}" && exit 0

FOUND=0

ALL_PATTERNS=("${SECRET_PATTERNS[@]}" "${PII_PATTERNS[@]}")

for file in $STAGED_FILES; do
    [[ ! -f "$file" ]] && continue

    # Skip binary/media
    skip=0
    for sp in "${SKIP_PATTERNS[@]}"; do
        [[ "$file" =~ $sp ]] && skip=1 && break
    done
    [[ $skip -eq 1 ]] && continue

    # Check each pattern against file content
    for pattern in "${ALL_PATTERNS[@]}"; do
        matches=$(grep -nE "$pattern" "$file" 2>/dev/null || true)
        if [[ -n "$matches" ]]; then
            echo -e "${RED}⚠️  [$file] matches: $pattern${NC}"
            echo "$matches" | head -3
            echo ""
            FOUND=1
        fi
    done
done

if [[ $FOUND -eq 1 ]]; then
    echo -e "${RED}❌ BLOCKED: secrets or PII detected in staged files.${NC}"
    echo ""
    echo "Options:"
    echo "  1. Remove the PII/secret from the file"
    echo "  2. Add pattern exception to .pii-patterns with # comment"
    echo "  3. Skip check (private repos only): git commit --no-verify"
    exit 1
else
    echo -e "${GREEN}✓ No secrets or PII detected${NC}"
    exit 0
fi
