# security — openclaw bot hardening

defense-in-depth для personal AI assistant на openclaw. 5 уровней, каждый ловит то что пропустил предыдущий.

```
Layer 1: PROMPT        — behavioral rules, anti-injection, role-based access
Layer 2: OS ISOLATION   — systemd hardening, egress filter (UFW), file permissions
Layer 3: EXEC SANDBOX   — bwrap namespace isolation + fs-guard + SOPS vault
Layer 4: OUTPUT DLP     — regex + entropy + known secrets scanning (post-send)
Layer 5: BLAST RADIUS   — spend limits, API key restrictions, rotation runbook
```

## docs

| doc | что | время |
|-----|-----|-------|
| [security-philosophy.md](security-philosophy.md) | архитектура defense-in-depth, threat model, gaps, lessons learned | 15 мин чтения |
| [exec-sandbox-playbook.md](exec-sandbox-playbook.md) | bwrap sandbox setup (recommended), allowlist (legacy), docker (not recommended) | 30 мин setup |

## hooks (в этом репо)

| hook | layer | что |
|------|-------|-----|
| [sandbox-exec](../../hooks/sandbox-exec/) | 3 (exec) | **bwrap namespace isolation** — каждая Bash команда в изолированном namespace, секреты невидимы |
| [fs-guard](../../hooks/fs-guard/) | 3 (fs) | **workspace-only file access** — Read/Edit/Write/Glob/Grep только workspace + /tmp |
| [output-filter](../../hooks/output-filter/) | 4 (DLP) | post-send detection секретов в исходящих сообщениях (regex + entropy + known secrets) |
| [memory-logger](../../hooks/memory-logger/) | — | raw log всех message events (memory pipeline) |

## scripts (в этом репо)

| script | что |
|--------|-----|
| [setup-vault.sh](../../scripts/setup-vault.sh) | SOPS+age vault — шифрует .env, decrypt в tmpfs (RAM) при старте |
| [pentest-basic.sh](../../scripts/pentest-basic.sh) | проверка всех слоёв защиты — bwrap, fs-guard, vault, DLP, settings |
| [check-secrets.sh](../../scripts/check-secrets.sh) | grep по workspace на утечки ключей |
| [pre-commit-secrets-check.sh](../../scripts/pre-commit-secrets-check.sh) | pre-commit hook — блокирует коммит с секретами |

## tools

| tool | что |
|------|-----|
| [secureclaw](https://github.com/matskevich/openclaw-brain/tree/main/skills/secureclaw) | 42-check automated security audit, OWASP ASI mapping, `--telegram` reporter |

## quick start

### 1. проверь: у тебя проблема?

пошли боту:

```
запусти: python3 -c "print('hello')"
```

- ответил `hello` без sandbox → **у тебя проблема**, читай дальше
- команда в bwrap → уже защищён

### 2. установи за 30 минут

```bash
# клонируй этот репо
git clone https://github.com/matskevich/openclaw-infra.git
cd openclaw-infra

# 1. bwrap sandbox (Layer 3 — exec isolation)
apt install bubblewrap jq
cp hooks/sandbox-exec/hook.sh ~/workspace/hooks/sandbox-exec/hook.sh
# отредактируй WORKSPACE и HOME_DIR в hook.sh

# 2. fs-guard (Layer 3 — file isolation)
cp hooks/fs-guard/hook.sh ~/workspace/hooks/fs-guard/hook.sh
# отредактируй WORKSPACE в hook.sh

# 3. vault (optional — encrypt .env)
./scripts/setup-vault.sh

# 4. DLP (Layer 4 — leak detection)
cp hooks/output-filter/handler.ts ~/workspace/hooks/output-filter/handler.ts

# 5. добавь хуки в settings.json
# см. exec-sandbox-playbook.md для полного конфига

# 6. проверь
./scripts/pentest-basic.sh ~/workspace/hooks
```

### 3. или отдай claude code

скопируй промпт из [exec-sandbox-playbook.md](exec-sandbox-playbook.md) и отправь своему claude code.

## key insight (260216)

**docker sandbox ≠ universal solution.** openclaw's `sandbox.mode` moves workspaces → breaks memory, heartbeat, skills. **bwrap** wraps individual commands without relocating anything — recommended approach.

**exec approvals = friction, not enforcement.** bwrap provides real namespace isolation. approval popups killed bot autonomy without adding real security.

**enforcement first, prompting second.** prompt rules = UX/policy. bwrap/fs-guard = actual enforcement.
