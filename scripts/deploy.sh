#!/bin/bash
set -e

# DEPRECATED: Use ./scripts/sync.sh instead
#
# This script is kept for backwards compatibility.
# It now delegates to sync.sh push (safe two-way sync).
#
# Recommended workflow:
#   1. ./scripts/sync.sh pull   # Get bot's changes first
#   2. Make changes (AGENTS.md, SECURITY.md)
#   3. ./scripts/sync.sh push   # Deploy with safety checks
#
# Or use this script (calls sync.sh push):
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "⚠️  deploy.sh is deprecated"
echo "Using sync.sh push instead (safer, two-way sync)"
echo ""

# Delegate to sync.sh
exec "$SCRIPT_DIR/sync.sh" push
