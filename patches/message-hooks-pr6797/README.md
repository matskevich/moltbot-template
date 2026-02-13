# message-hooks backport for openclaw v2026.2.3

## status: ✅ working

backport of message:received / message:sent for openclaw v2026.2.3

**source:** https://github.com/openclaw/openclaw/pull/6797
**public repo:** https://github.com/matskevich/openclaw-infra/tree/main/patches/message-hooks-pr6797

## result

```
hook: memory-logger -> message:received, message:sent
raw log: entries in raw/telegram/chats/<chat_id>/YYYY/MM/DD.jsonl
received + sent in same file, no duplicates
```

## installation

1. `git apply message-hooks-backport-v2026.2.3-final.patch`
2. `NODE_OPTIONS='--max-old-space-size=2048' pnpm build`
3. create hook in `~/clawd/hooks/memory-logger/`
4. add `CLAWD_WORKSPACE` to systemd
5. restart

full guide: `INSTALL.md`

## known issues (fixed in final patch)

- ~~duplicate entries (2x per message)~~ — fixed
- cfg.hooks = undefined — workaround in patch (3 places patched)
- handler syntax — use `!==` not `\!==` (bash escape issue)

## files

| file | description |
|------|-------------|
| `message-hooks-backport-v2026.2.3-final.patch` | recommended, all channels |
| `INSTALL.md` | step-by-step guide |
| `RESULTS.md` | production test results |

## channels supported

- telegram ✓ (tested)
- discord ✓
- imessage ✓
- signal ✓

## levin-inspired

raw log = canonical truth
- survives agent compaction
- identity outside substrate
- memory as infrastructure, not agent responsibility

## what it enables

- semantic search over all conversations (with embeddings)
- daily/weekly auto-digest
- people memory extraction
- conversation analytics
- goal tracking from raw data

see: `memory/goals/raw-log-evolution.md` on server

## related

- PR #6797: https://github.com/openclaw/openclaw/pull/6797
- issue #5053: https://github.com/openclaw/openclaw/issues/5053
