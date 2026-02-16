#!/bin/bash
# bwrap exec sandbox — PreToolUse hook for Bash
#
# wraps every Bash command in bubblewrap sandbox:
# - read-only bind: /usr, /bin, /lib, /lib64, /etc/resolv.conf, /etc/ssl
# - writable bind: workspace (YOUR_WORKSPACE)
# - tmpfs (empty): ~/.openclaw, ~/.ssh, ~/secrets, /run
# - unshare PID namespace, die with parent
#
# input: JSON on stdin (PreToolUse event)
# output: JSON on stdout with updatedInput (command wrapped in bwrap)
#
# install: add to ~/.openclaw/settings.json hooks section

set -euo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')

# only intercept Bash tool
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# =============================================
# CONFIGURE THESE FOR YOUR SETUP
# =============================================
WORKSPACE="$HOME/workspace"     # your bot's working directory
HOME_DIR="$HOME"                # bot user home
# =============================================

# --- skip list: commands needing real system access → deny ---
SKIP_PATTERNS=(
  "^systemctl "
  "^sudo "
  "^ssh "
  "^scp "
)

for pat in "${SKIP_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pat"; then
    jq -n '{
      hookSpecificOutput: {
        hookEventName: "PreToolUse",
        permissionDecision: "deny",
        permissionDecisionReason: "command requires system access — blocked by sandbox policy"
      }
    }'
    exit 0
  fi
done

# --- check bwrap ---

if ! command -v bwrap &>/dev/null; then
  jq -n '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      permissionDecisionReason: "WARNING: bwrap not installed, falling back without sandbox",
      additionalContext: "install bubblewrap for filesystem isolation"
    }
  }'
  exit 0
fi

# --- build bwrap command ---

BWRAP_CMD="bwrap"
BWRAP_CMD="$BWRAP_CMD --ro-bind /usr /usr"
BWRAP_CMD="$BWRAP_CMD --ro-bind /bin /bin"

# optional system dirs
[ -d /sbin ] && BWRAP_CMD="$BWRAP_CMD --ro-bind /sbin /sbin"
[ -d /lib ] && BWRAP_CMD="$BWRAP_CMD --ro-bind /lib /lib"
[ -d /lib64 ] && BWRAP_CMD="$BWRAP_CMD --ro-bind /lib64 /lib64"

# minimal /etc (DNS + TLS only)
BWRAP_CMD="$BWRAP_CMD --ro-bind /etc/resolv.conf /etc/resolv.conf"
BWRAP_CMD="$BWRAP_CMD --ro-bind /etc/ssl /etc/ssl"
[ -d /etc/alternatives ] && BWRAP_CMD="$BWRAP_CMD --ro-bind /etc/alternatives /etc/alternatives"
[ -f /etc/passwd ] && BWRAP_CMD="$BWRAP_CMD --ro-bind /etc/passwd /etc/passwd"
[ -f /etc/group ] && BWRAP_CMD="$BWRAP_CMD --ro-bind /etc/group /etc/group"
[ -f /etc/gitconfig ] && BWRAP_CMD="$BWRAP_CMD --ro-bind /etc/gitconfig /etc/gitconfig"

# proc + dev
BWRAP_CMD="$BWRAP_CMD --proc /proc"
BWRAP_CMD="$BWRAP_CMD --dev /dev"

# workspace: WRITABLE
BWRAP_CMD="$BWRAP_CMD --bind $WORKSPACE $WORKSPACE"

# /tmp: writable tmpfs
BWRAP_CMD="$BWRAP_CMD --tmpfs /tmp"

# HIDE secrets: mount empty tmpfs over sensitive dirs
BWRAP_CMD="$BWRAP_CMD --tmpfs $HOME_DIR/.openclaw"
BWRAP_CMD="$BWRAP_CMD --tmpfs $HOME_DIR/.ssh"
BWRAP_CMD="$BWRAP_CMD --tmpfs /run"

# add your secrets directory if you have one:
# BWRAP_CMD="$BWRAP_CMD --tmpfs $HOME_DIR/secrets"

# git support
[ -f "$HOME_DIR/.gitconfig" ] && BWRAP_CMD="$BWRAP_CMD --ro-bind $HOME_DIR/.gitconfig $HOME_DIR/.gitconfig"

# isolation
BWRAP_CMD="$BWRAP_CMD --unshare-pid"
BWRAP_CMD="$BWRAP_CMD --die-with-parent"
BWRAP_CMD="$BWRAP_CMD --chdir $WORKSPACE"

# base64 encode command to avoid quoting hell
CMD_B64=$(echo "$COMMAND" | base64 -w0)
SANDBOXED="$BWRAP_CMD -- /bin/bash -c \"\$(echo '$CMD_B64' | base64 -d)\""

# return modified command
jq -n --arg cmd "$SANDBOXED" --arg orig "$COMMAND" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "allow",
    permissionDecisionReason: ("sandbox: " + $orig),
    updatedInput: {
      command: $cmd
    }
  }
}'
exit 0
