#!/usr/bin/env bash
set -euo pipefail

# secure.sh — exec sandbox + watchdog за 1 минуту
# usage: bash secure.sh [--docker]
#
# что делает:
#   1. backup конфига
#   2. создаёт exec-approvals.json (18 safe bins)
#   3. патчит openclaw.json (allowlist + ask: on-miss)
#   4. ставит config-watchdog.sh в cron (5 мин)
#   5. рестартит бота
#
# --docker: + docker sandbox (non-main mode, needs sudo)

DOCKER=false
[[ "${1:-}" == "--docker" ]] && DOCKER=true

# detect openclaw home
OC_HOME="${HOME}/.openclaw"
if [ ! -f "${OC_HOME}/openclaw.json" ]; then
    echo "ERROR: ${OC_HOME}/openclaw.json not found"
    echo "run this on the server where your openclaw bot is running"
    exit 1
fi

CONFIG="${OC_HOME}/openclaw.json"
APPROVALS="${OC_HOME}/exec-approvals.json"
SCRIPTS_DIR="${HOME}/scripts"
LOGS_DIR="${HOME}/logs"

echo "=== openclaw exec sandbox setup ==="
echo "config: ${CONFIG}"
echo "docker: ${DOCKER}"
echo ""

# 1. backup
BACKUP="${CONFIG}.bak.$(date +%Y%m%d_%H%M%S)"
cp "${CONFIG}" "${BACKUP}"
echo "[1/5] backup → ${BACKUP}"

# 2. exec-approvals.json
cat > "${APPROVALS}" << 'APPROVALS_EOF'
{
  "version": 1,
  "defaults": {
    "security": "allowlist",
    "ask": "on-miss",
    "askFallback": "deny"
  },
  "agents": {
    "*": {
      "allowlist": [
        { "pattern": "/usr/bin/git" },
        { "pattern": "/usr/bin/ls" },
        { "pattern": "/usr/bin/find" },
        { "pattern": "/usr/bin/mkdir" },
        { "pattern": "/usr/bin/cp" },
        { "pattern": "/usr/bin/mv" },
        { "pattern": "/usr/bin/date" },
        { "pattern": "/usr/bin/diff" },
        { "pattern": "/usr/bin/dirname" },
        { "pattern": "/usr/bin/basename" },
        { "pattern": "/usr/bin/stat" },
        { "pattern": "/usr/bin/unzip" },
        { "pattern": "/usr/bin/jq" },
        { "pattern": "/usr/bin/df" },
        { "pattern": "/usr/bin/du" },
        { "pattern": "/usr/bin/wc" },
        { "pattern": "/usr/bin/realpath" },
        { "pattern": "/usr/bin/readlink" }
      ]
    }
  }
}
APPROVALS_EOF
chmod 600 "${APPROVALS}"
echo "[2/5] exec-approvals.json → 18 bins"

# 3. patch openclaw.json
python3 << PYEOF
import json
with open("${CONFIG}") as f:
    cfg = json.load(f)
cfg.setdefault("tools", {}).setdefault("exec", {})
cfg["tools"]["exec"]["host"] = "gateway"
cfg["tools"]["exec"]["security"] = "allowlist"
cfg["tools"]["exec"]["ask"] = "on-miss"
with open("${CONFIG}", "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
print("[3/5] openclaw.json patched (allowlist + ask: on-miss)")
PYEOF

# 4. config watchdog
mkdir -p "${SCRIPTS_DIR}" "${LOGS_DIR}"

cat > "${SCRIPTS_DIR}/config-watchdog.sh" << 'WATCHDOG_EOF'
#!/usr/bin/env bash
set -euo pipefail

CONFIG="$HOME/.openclaw/openclaw.json"
APPROVALS="$HOME/.openclaw/exec-approvals.json"
LOG="/tmp/config-watchdog.log"

# get bot token for alerts (best effort)
BOT_TOKEN=$(python3 -c "
import json
with open('$CONFIG') as f:
    print(json.load(f)['channels']['telegram']['botToken'])
" 2>/dev/null || true)

# get owner chat id
CHAT_ID=$(python3 -c "
import json
with open('$CONFIG') as f:
    cfg = json.load(f)
af = cfg.get('channels',{}).get('telegram',{}).get('allowFrom',[])
print(af[0] if af else '')
" 2>/dev/null || true)

ISSUES=""

# check openclaw.json security keys
read -r ASK SEC SAFEBINS < <(python3 -c "
import json
with open('$CONFIG') as f:
    cfg = json.load(f)
e = cfg.get('tools',{}).get('exec',{})
print(
    e.get('ask','?'),
    e.get('security','?'),
    len(e.get('safeBins',[]))
)
" 2>/dev/null || echo "? ? 0")

[ "$ASK" != "on-miss" ] && ISSUES="${ISSUES}tools.exec.ask=${ASK} (want: on-miss)\n"
[ "$SEC" != "allowlist" ] && ISSUES="${ISSUES}tools.exec.security=${SEC} (want: allowlist)\n"
[ "$SAFEBINS" != "0" ] && ISSUES="${ISSUES}safeBins count=${SAFEBINS} (want: 0)\n"

# check exec-approvals.json for banned binaries
if [ -f "$APPROVALS" ]; then
    BANNED=$(python3 -c "
import json
BANNED = {'/usr/bin/bash', '/usr/bin/sh', '/usr/bin/python3', '/usr/bin/python', '/usr/bin/node', '/usr/bin/cat', '/usr/bin/curl', '/usr/bin/wget', '/usr/bin/env'}
with open('$APPROVALS') as f:
    d = json.load(f)
found = []
for name, cfg in d.get('agents', {}).items():
    for e in cfg.get('allowlist', []):
        p = e.get('pattern', '') if isinstance(e, dict) else str(e)
        if p in BANNED:
            found.append(f'{name}:{p}')
print(' '.join(found) if found else 'clean')
" 2>/dev/null || echo "clean")
    [ "$BANNED" != "clean" ] && ISSUES="${ISSUES}BANNED in allowlist: ${BANNED}\n"
fi

if [ -n "$ISSUES" ]; then
    # auto-fix
    python3 -c "
import json
with open('$CONFIG') as f:
    cfg = json.load(f)
cfg.setdefault('tools',{}).setdefault('exec',{})
cfg['tools']['exec']['ask'] = 'on-miss'
cfg['tools']['exec']['security'] = 'allowlist'
cfg['tools']['exec'].pop('safeBins', None)
with open('$CONFIG', 'w') as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
" 2>/dev/null || true

    if [ -f "$APPROVALS" ]; then
        python3 -c "
import json
BANNED = {'/usr/bin/bash', '/usr/bin/sh', '/usr/bin/python3', '/usr/bin/python', '/usr/bin/node', '/usr/bin/cat', '/usr/bin/curl', '/usr/bin/wget', '/usr/bin/env'}
with open('$APPROVALS') as f:
    d = json.load(f)
for name in list(d.get('agents', {}).keys()):
    al = d['agents'][name].get('allowlist', [])
    filtered = [e for e in al if (e.get('pattern','') if isinstance(e,dict) else str(e)) not in BANNED]
    if len(filtered) != len(al):
        d['agents'][name]['allowlist'] = filtered
with open('$APPROVALS', 'w') as f:
    json.dump(d, f, indent=2, ensure_ascii=False)
" 2>/dev/null || true
    fi

    # alert (best effort)
    if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
        MSG=$(printf "config tamper detected + auto-reverted\n\n%b\nconfig restored." "$ISSUES")
        curl -sf -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            -d chat_id="$CHAT_ID" \
            --data-urlencode "text=${MSG}" > /dev/null 2>&1 || true
    fi
    echo "[$(date)] TAMPER: ${ISSUES}" >> "$LOG"
else
    echo "[$(date)] OK" >> "$LOG"
fi
WATCHDOG_EOF
chmod +x "${SCRIPTS_DIR}/config-watchdog.sh"

# add to cron if not already there
if ! crontab -l 2>/dev/null | grep -q "config-watchdog"; then
    (crontab -l 2>/dev/null; echo "*/5 * * * * ${SCRIPTS_DIR}/config-watchdog.sh 2>/dev/null") | crontab -
    echo "[4/5] watchdog → cron (every 5 min)"
else
    echo "[4/5] watchdog already in cron"
fi

# 5. docker (optional)
if [ "$DOCKER" = true ]; then
    echo ""
    echo "=== docker sandbox setup ==="
    if ! command -v docker &>/dev/null; then
        echo "installing docker..."
        sudo apt-get update -qq && sudo apt-get install -y -qq docker.io
    fi
    if ! groups | grep -q docker; then
        sudo usermod -aG docker "$(whoami)"
        echo "added $(whoami) to docker group"
        echo "IMPORTANT: restarting systemd user manager..."
        sudo systemctl restart "user@$(id -u)"
    fi
    # patch config
    python3 << DOCKER_PYEOF
import json
with open("${CONFIG}") as f:
    cfg = json.load(f)
cfg.setdefault("agents", {}).setdefault("defaults", {}).setdefault("sandbox", {})["mode"] = "non-main"
with open("${CONFIG}", "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
print("sandbox.mode: non-main")
DOCKER_PYEOF
    echo "docker sandbox configured (non-main)"
fi

# restart bot
echo ""
BOT_SERVICE=""
for svc in moltbot openclaw-gateway openclaw; do
    if systemctl --user is-enabled "${svc}.service" 2>/dev/null | grep -q enabled; then
        BOT_SERVICE="${svc}"
        break
    fi
done

if [ -n "$BOT_SERVICE" ]; then
    systemctl --user restart "${BOT_SERVICE}"
    echo "[5/5] restarted ${BOT_SERVICE}.service"
else
    echo "[5/5] SKIP: no bot service found (restart manually)"
fi

echo ""
echo "=== DONE ==="
echo ""
echo "test: send your bot this message:"
echo '  запусти: python3 -c "print(42)"'
echo ""
echo "expected: approval buttons (Allow Once / Always / Deny)"
echo "if bot answers '42' without buttons — something is wrong"
echo ""
echo "docs: https://github.com/matskevich/openclaw-infra/blob/main/docs/security/exec-sandbox-playbook.md"
