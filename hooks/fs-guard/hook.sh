#!/bin/bash
# fs-guard — PreToolUse hook for Read/Edit/Write/Glob/Grep
#
# restricts file access to workspace only:
# - ALLOWED: $WORKSPACE/**, /tmp/**
# - BLOCKED: everything else (~/.openclaw/, /run/, /etc/, ~/.ssh/)
#
# input: JSON on stdin (PreToolUse event)
# output: JSON on stdout with permissionDecision deny (or silent exit 0 for allow)
#
# install: add to ~/.openclaw/settings.json hooks section

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')

# =============================================
# CONFIGURE THIS FOR YOUR SETUP
# =============================================
WORKSPACE="$HOME/workspace"     # your bot's working directory
# =============================================

# extract path based on tool type
case "$TOOL_NAME" in
  Read|Write|Edit)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')
    ;;
  Glob)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // ""')
    if [ -z "$FILE_PATH" ]; then
      exit 0  # glob with no path = cwd, allow
    fi
    ;;
  Grep)
    FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.path // ""')
    if [ -z "$FILE_PATH" ]; then
      exit 0  # grep with no path = cwd, allow
    fi
    ;;
  *)
    exit 0  # not our tool
    ;;
esac

if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# resolve symlinks and .. traversal
# -m: don't require file to exist. fallback: python3 normpath, then raw path
RESOLVED=$(realpath -m "$FILE_PATH" 2>/dev/null \
  || python3 -c "import os,sys; print(os.path.normpath(sys.argv[1]))" "$FILE_PATH" 2>/dev/null \
  || echo "$FILE_PATH")

# defense in depth: if path still contains .., deny
if [[ "$RESOLVED" == *".."* ]]; then
  jq -n --arg path "$FILE_PATH" --arg tool "$TOOL_NAME" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("fs-guard: " + $tool + " blocked — path traversal: " + $path)
    }
  }'
  exit 0
fi

# allowed prefixes
ALLOWED=(
  "$WORKSPACE"
  "/tmp"
)

BLOCKED=true
for prefix in "${ALLOWED[@]}"; do
  if [[ "$RESOLVED" == "$prefix" || "$RESOLVED" == "$prefix/"* ]]; then
    BLOCKED=false
    break
  fi
done

if [ "$BLOCKED" = true ]; then
  jq -n --arg path "$RESOLVED" --arg tool "$TOOL_NAME" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: ("fs-guard: " + $tool + " blocked on " + $path + " (outside workspace)")
    }
  }'
  exit 0
fi

# allowed — silent pass
exit 0
