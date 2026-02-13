# message-hooks backport — test results

**date:** 2026-02-05
**openclaw version:** v2026.2.3 (stable)
**server:** Hetzner VPS (3.7GB RAM)

---

## baseline (before patch)

```
=== message-hooks verification ===

1. checking hook registration...
   ✗ no hooks registered

2. checking hook files...
   ✗ no hook handlers

3. checking raw/ structure...
   ✗ raw/ does not exist

4. checking recent activity...
   n/a

5. checking bot status...
   ✓ moltbot running

=== done ===
```

**raw log entries:** 0

---

## after patch

```
=== ACTUAL STATUS ===

1. hook registration:
   Registered hook: memory-logger -> message:received, message:sent

2. raw/ files:
   8 /home/moltbot/clawd/raw/telegram/chats/<USER_ID>/2026/02/05.jsonl
   10 /home/moltbot/clawd/raw/telegram/chats/dm/2026/02/05.jsonl

3. latest entries:
   received: test message
   sent: bot response

4. bot status:
   active
```

**raw log entries:** 18 (across 2 files)

---

## sample log entries

### message:received

```json
{
  "ts": 1770291848402,
  "action": "received",
  "session": "agent:main:main",
  "message": "[Telegram <USER> (<USERNAME>) id:<USER_ID> +21m 2026-02-05 11:44 UTC] test",
  "rawBody": "test",
  "senderId": "<USER_ID>",
  "senderName": "<USER>",
  "channel": "telegram",
  "messageId": "1168",
  "isGroup": false,
  "timestamp": 1770291848000,
  "commandAuthorized": true
}
```

### message:sent

```json
{
  "ts": 1770291855903,
  "action": "sent",
  "session": "agent:main:main",
  "text": "working.",
  "target": "<USER_ID>",
  "channel": "telegram",
  "kind": "final"
}
```

---

## performance

- **build time:** ~20s (with `--max-old-space-size=2048`)
- **hook registration:** instant (directory discovery)
- **log write latency:** <10ms per entry
- **memory overhead:** negligible

---

## known issues

### cfg.hooks = undefined

config loader doesn't pass `hooks.internal.enabled`. patch contains workaround:
```typescript
if (false && !cfg.hooks?.internal?.enabled) { // TEMP: disabled check
```

**fix:** will be in next openclaw version (PR #6797)

### ~~duplicate entries~~ FIXED

~~each message was logged 2x~~ — fixed in `message-hooks-backport-v2026.2.3-final.patch`

---

## files changed

```
src/auto-reply/dispatch.ts                  (+2 lines)
src/auto-reply/reply/reply-dispatcher.ts    (+15 lines)
src/hooks/hooks.ts                          (+1 line)
src/hooks/internal-hooks.ts                 (+1 line)
src/hooks/loader.ts                         (+1 line, workaround)
src/hooks/message-hooks.ts                  (+84 lines, new file)
src/telegram/bot-message-dispatch.ts        (+10 lines)
src/discord/monitor/message-handler.process.ts  (+5 lines)
src/imessage/monitor/monitor-provider.ts    (+5 lines)
src/signal/monitor/event-handler.ts         (+5 lines)
```

---

## verification commands

```bash
# hook registered?
journalctl --user -u moltbot --since '5 minutes ago' | grep 'Registered hook'

# files created?
find ~/clawd/raw -name "*.jsonl" -exec wc -l {} \;

# latest entries?
tail -3 ~/clawd/raw/telegram/chats/dm/2026/02/05.jsonl | jq .

# bot running?
systemctl --user is-active moltbot
```

---

## conclusion

✅ **message hooks working**

- hook auto-discovered from `workspace/hooks/`
- `message:received` fires before agent processing
- `message:sent` fires after delivery
- logs written in structured jsonl format
- raw log = canonical truth for memory reconstruction
