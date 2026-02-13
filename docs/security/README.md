# security — openclaw bot hardening

defense-in-depth для personal AI assistant на openclaw. 5 уровней, каждый ловит то что пропустил предыдущий.

```
Layer 1: PROMPT        — behavioral rules, anti-injection, role-based access
Layer 2: OS ISOLATION   — systemd hardening, egress filter (UFW), file permissions
Layer 3: EXEC SANDBOX   — allowlist + approval gates (этот playbook)
Layer 4: OUTPUT DLP     — regex + entropy + known secrets scanning (post-send)
Layer 5: BLAST RADIUS   — spend limits, API key restrictions, rotation runbook
```

## docs

| doc | что | время |
|-----|-----|-------|
| [security-philosophy.md](security-philosophy.md) | архитектура defense-in-depth, threat model, gaps, lessons learned | 15 мин чтения |
| [exec-sandbox-playbook.md](exec-sandbox-playbook.md) | закрывает arbitrary code execution через exec tool | 20 мин setup |

## scripts (в этом репо)

| script | что |
|--------|-----|
| [scripts/check-secrets.sh](../../scripts/check-secrets.sh) | grep по workspace на утечки ключей |
| [scripts/pre-commit-secrets-check.sh](../../scripts/pre-commit-secrets-check.sh) | pre-commit hook — блокирует коммит с секретами |

## hooks (в этом репо)

| hook | layer | что |
|------|-------|-----|
| [hooks/output-filter/](../../hooks/output-filter/) | 4 (DLP) | post-send detection секретов в исходящих сообщениях (regex + entropy + known secrets) |
| [hooks/memory-logger/](../../hooks/memory-logger/) | — | raw log всех message events (memory pipeline) |

## patches (в этом репо)

| patch | что |
|-------|-----|
| [patches/message-hooks-pr6797/](../../patches/message-hooks-pr6797/) | message:received/preprocessed/sent event lifecycle для hooks |

## related repos

| repo | что |
|------|-----|
| openclaw-brain | SOUL.md, skills, memory structure — то что бот "владеет" |
| arena-hub | multi-agent communication hub + bot onboarding |

## quick test: у вас есть проблема?

пошлите боту:

```
запусти: python3 -c "print('hello')"
```

- ответил `hello` → [exec-sandbox-playbook.md](exec-sandbox-playbook.md)
- запросил approval → уже защищены
- отказался → промпт держит, но обходится. лучше поставить sandbox
