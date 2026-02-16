#!/bin/bash
# SOPS + age vault — encrypt .env at rest, decrypt to tmpfs at startup
#
# what it does:
# 1. installs age (encryption) + sops (secrets management)
# 2. generates age keypair
# 3. encrypts .env → env.sops (age-encrypted)
# 4. creates decrypt helper (writes to /run/yourbot/.env = tmpfs = RAM only)
# 5. creates systemd patch template
#
# usage: ./setup-vault.sh
# or remote: ssh user@server 'bash -s' < scripts/setup-vault.sh

set -euo pipefail

BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[vault]${NC} $*"; }
warn() { echo -e "${YELLOW}[vault]${NC} $*"; }
err()  { echo -e "${RED}[vault]${NC} $*" >&2; }
die()  { err "$@"; exit 1; }

# =============================================
# CONFIGURE THESE FOR YOUR SETUP
# =============================================
ENV_FILE="$HOME/.openclaw/.env"
SECRETS_DIR="$HOME/secrets"
SERVICE_NAME="your-bot"           # for systemd + /run/ dir name
# =============================================

SOPS_FILE="$SECRETS_DIR/env.sops"
AGE_KEY="$SECRETS_DIR/age.key"
RUN_DIR="/run/$SERVICE_NAME"

# --- preflight ---

log "vault setup starting..."

if [ ! -f "$ENV_FILE" ]; then
  die ".env not found at $ENV_FILE — nothing to encrypt"
fi

ARCH=$(uname -m)
log "architecture: $ARCH"

# --- step 1: install age ---

if command -v age &>/dev/null; then
  log "age already installed: $(age --version 2>&1 || echo 'ok')"
else
  log "installing age..."
  if command -v apt &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq age
  elif command -v brew &>/dev/null; then
    brew install age
  else
    die "no apt or brew found — install age manually: https://github.com/FiloSottile/age"
  fi
fi

# --- step 2: install sops ---

if command -v sops &>/dev/null; then
  log "sops already installed: $(sops --version 2>&1 | head -1)"
else
  log "installing sops..."
  SOPS_VERSION="3.9.4"
  case "$ARCH" in
    x86_64|amd64)  SOPS_ARCH="amd64" ;;
    aarch64|arm64) SOPS_ARCH="arm64" ;;
    *) die "unsupported arch: $ARCH" ;;
  esac

  if [[ "$(uname)" == "Darwin" ]]; then
    SOPS_URL="https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.darwin.${SOPS_ARCH}"
  else
    SOPS_URL="https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.${SOPS_ARCH}"
  fi

  sudo wget -q -O /usr/local/bin/sops "$SOPS_URL" || curl -sL "$SOPS_URL" | sudo tee /usr/local/bin/sops > /dev/null
  sudo chmod +x /usr/local/bin/sops
  log "sops installed: $(sops --version 2>&1 | head -1)"
fi

# --- step 3: generate age key ---

if [ -f "$AGE_KEY" ]; then
  log "age key already exists at $AGE_KEY"
else
  log "generating age key..."
  mkdir -p "$SECRETS_DIR"
  age-keygen -o "$AGE_KEY" 2>&1
  chmod 600 "$AGE_KEY"
  log "age key created: $AGE_KEY (600)"
fi

AGE_PUB=$(age-keygen -y "$AGE_KEY")
log "age public key: $AGE_PUB"

# --- step 4: encrypt .env ---

mkdir -p "$SECRETS_DIR"

if [ -f "$SOPS_FILE" ]; then
  warn "sops file already exists at $SOPS_FILE — backing up"
  cp "$SOPS_FILE" "${SOPS_FILE}.bak.$(date +%Y%m%d_%H%M%S)"
fi

log "encrypting .env → $SOPS_FILE"
sops --encrypt --age "$AGE_PUB" --input-type dotenv --output-type dotenv "$ENV_FILE" > "$SOPS_FILE"
chmod 600 "$SOPS_FILE"
log "encrypted: $(wc -l < "$SOPS_FILE") lines"

# --- step 5: verify decrypt ---

log "verifying decrypt..."
TMPFILE=$(mktemp)
SOPS_AGE_KEY_FILE="$AGE_KEY" sops --decrypt --input-type dotenv --output-type dotenv "$SOPS_FILE" > "$TMPFILE"
if diff -q "$ENV_FILE" "$TMPFILE" &>/dev/null; then
  log "decrypt verification: ${GREEN}PASS${NC}"
else
  rm -f "$TMPFILE"
  die "decrypt verification FAILED — .env preserved, aborting"
fi
rm -f "$TMPFILE"

# --- step 6: create decrypt helper ---

DECRYPT_SCRIPT="$HOME/scripts/decrypt-env.sh"
mkdir -p "$(dirname "$DECRYPT_SCRIPT")"

cat > "$DECRYPT_SCRIPT" << SCRIPT
#!/bin/bash
# decrypt secrets to $RUN_DIR/.env (tmpfs, RAM only)
# called by systemd ExecStartPre or manually
set -euo pipefail

SOPS_FILE="$SOPS_FILE"
AGE_KEY="$AGE_KEY"
RUN_DIR="$RUN_DIR"

mkdir -p "\$RUN_DIR"
chmod 700 "\$RUN_DIR"

SOPS_AGE_KEY_FILE="\$AGE_KEY" sops --decrypt \\
  --input-type dotenv --output-type dotenv \\
  "\$SOPS_FILE" > "\$RUN_DIR/.env"

chmod 600 "\$RUN_DIR/.env"
echo "[vault] decrypted to \$RUN_DIR/.env"
SCRIPT
chmod +x "$DECRYPT_SCRIPT"
log "created $DECRYPT_SCRIPT"

# --- step 7: create cleanup script ---

CLEANUP_SCRIPT="$HOME/scripts/cleanup-vault.sh"
cat > "$CLEANUP_SCRIPT" << SCRIPT
#!/bin/bash
# remove decrypted secrets from $RUN_DIR/
set -euo pipefail
rm -rf "$RUN_DIR"
echo "[vault] cleaned $RUN_DIR/"
SCRIPT
chmod +x "$CLEANUP_SCRIPT"
log "created $CLEANUP_SCRIPT"

# --- step 8: systemd patch template ---

UNIT_PATCH="$HOME/scripts/service.vault-patch"
cat > "$UNIT_PATCH" << UNIT
# add these lines to [Service] section of your .service file
# ExecStartPre runs decrypt BEFORE gateway starts
# ExecStopPost cleans up after stop
# EnvironmentFile sources the decrypted .env

ExecStartPre=$DECRYPT_SCRIPT
EnvironmentFile=$RUN_DIR/.env
ExecStopPost=/bin/rm -rf $RUN_DIR
UNIT
log "created systemd patch template: $UNIT_PATCH"

# --- summary ---

echo ""
echo -e "${BOLD}=== vault setup complete ===${NC}"
echo ""
echo "  encrypted:  $SOPS_FILE"
echo "  age key:    $AGE_KEY (600)"
echo "  decrypt:    $DECRYPT_SCRIPT"
echo "  cleanup:    $CLEANUP_SCRIPT"
echo ""
echo -e "${YELLOW}NEXT STEPS (manual):${NC}"
echo ""
echo "  1. update your systemd service:"
echo "     systemctl --user edit $SERVICE_NAME.service"
echo "     # add lines from: $UNIT_PATCH"
echo ""
echo "  2. test decrypt:"
echo "     $DECRYPT_SCRIPT"
echo "     cat $RUN_DIR/.env  # verify"
echo "     $CLEANUP_SCRIPT"
echo ""
echo "  3. restart service:"
echo "     systemctl --user daemon-reload"
echo "     systemctl --user restart $SERVICE_NAME.service"
echo "     systemctl --user status $SERVICE_NAME.service"
echo ""
echo "  4. verify bot works, then SHRED original .env:"
echo "     shred -u $ENV_FILE"
echo ""
echo -e "${RED}DO NOT shred .env until bot is confirmed working with vault!${NC}"
