#!/bin/bash
# Check for secrets in staged files
# Usage: ./check-secrets.sh [files...]
# Exit 1 if secrets found

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Patterns to detect (regex)
PATTERNS=(
  'sk-ant-[a-zA-Z0-9_-]{20,}'           # Anthropic API key
  'sk-proj-[a-zA-Z0-9_-]{20,}'          # OpenAI API key  
  'sk-[a-zA-Z0-9]{48}'                   # OpenAI old format
  'gsk_[a-zA-Z0-9]{50,}'                 # Groq API key
  'AIzaSy[a-zA-Z0-9_-]{33}'              # Google API key
  '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' # UUID (Exa, etc)
  '[0-9]{10}:[A-Za-z0-9_-]{35}'          # Telegram bot token
  '\b[0-9a-f]{64}\b'                      # 256-bit hex (gateway token, etc)
  'HETZNER_API_TOKEN=[A-Za-z0-9]{64}'    # Hetzner API token (env assignment)
  '\bH(CLOUD|DNS)?[A-Za-z0-9]{60,64}\b' # Hetzner API token (bare value)
)

# Files to always skip
SKIP_PATTERNS=(
  '\.env\.example$'
  'check-secrets\.sh$'
  'SECURITY\.md$'
  '\.gitignore$'
  'audit-.*\.md$'
)

FILES="${@:-$(git diff --cached --name-only --diff-filter=ACM)}"
FOUND=0

for file in $FILES; do
  # Skip binary files
  [[ ! -f "$file" ]] && continue
  file -b --mime-type "$file" | grep -q '^text/' || continue
  
  # Skip allowed files
  skip=0
  for pattern in "${SKIP_PATTERNS[@]}"; do
    [[ "$file" =~ $pattern ]] && skip=1 && break
  done
  [[ $skip -eq 1 ]] && continue
  
  # Check each pattern
  for pattern in "${PATTERNS[@]}"; do
    matches=$(grep -nE "$pattern" "$file" 2>/dev/null || true)
    if [[ -n "$matches" ]]; then
      echo -e "${RED}⚠️  Possible secret in $file:${NC}"
      echo "$matches" | head -3
      FOUND=1
    fi
  done
done

if [[ $FOUND -eq 1 ]]; then
  echo ""
  echo -e "${RED}❌ Secrets detected! Commit blocked.${NC}"
  echo "Fix: Move secrets to env vars or .env file"
  exit 1
else
  echo -e "${GREEN}✓ No secrets detected${NC}"
  exit 0
fi
