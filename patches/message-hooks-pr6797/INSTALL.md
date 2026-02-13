# message-hooks backport — installation guide

patch adds `message:received` and `message:sent` hook events to openclaw.

**source:** https://github.com/openclaw/openclaw/pull/6797
**tested on:** openclaw v2026.2.3 (stable)

---

## checklist

- [ ] openclaw v2026.2.3 (stable)
- [ ] node 22+
- [ ] pnpm installed
- [ ] patch applied
- [ ] hook handler created with proper HOOK.md
- [ ] package.json added to hook directory
- [ ] CLAWD_WORKSPACE added to systemd
- [ ] moltbot restarted
- [ ] logs appearing in raw/

---

## step 1: apply patch

```bash
cd ~/moltbot-src
git stash  # save local changes if any

# apply patch
git apply ~/path/to/message-hooks-backport-v2026.2.3-final.patch

# if conflicts:
git apply --3way ~/path/to/message-hooks-backport-v2026.2.3-final.patch
```

**verify:**
```bash
grep -r "triggerMessageReceived" src/
```
should find:
- `src/auto-reply/dispatch.ts`
- `src/hooks/message-hooks.ts`
- `src/telegram/bot-message-dispatch.ts`

---

## step 2: build

**warning:** stop bot before build (free up RAM)

```bash
systemctl --user stop moltbot
pnpm install
NODE_OPTIONS='--max-old-space-size=2048' pnpm build
```

**expected output (end):**
```
✔ Build complete in XXXXms
[copy-hook-metadata] Done
```

---

## step 3: create hook handler

```bash
mkdir -p ~/clawd/hooks/memory-logger
```

create `~/clawd/hooks/memory-logger/HOOK.md`:

```markdown
---
name: memory-logger
description: "Write all messages to raw log"
metadata:
  {
    "openclaw":
      {
        "emoji": "💾",
        "events": ["message:received", "message:sent"],
      },
  }
---

# memory-logger

writes all messages to raw log (layer 1 of memory architecture).
```

create `~/clawd/hooks/memory-logger/package.json`:

```json
{"type": "module"}
```

create `~/clawd/hooks/memory-logger/handler.ts`:

```typescript
import { appendFileSync, mkdirSync, existsSync } from "fs";
import { join, dirname } from "path";

type MessageEvent = {
  type: "message";
  action: "received" | "sent";
  sessionKey: string;
  context: {
    message?: string;
    rawBody?: string;
    senderId?: string;
    senderName?: string;
    channel?: string;
    messageId?: string;
    isGroup?: boolean;
    groupId?: string;
    timestamp?: number;
    text?: string;
    target?: string;
    kind?: string;
  };
};

export default async function handler(event: MessageEvent): Promise<void> {
  if (event.type !== "message") return;

  const now = new Date();
  const channel = event.context.channel ?? "unknown";
  const chatId = event.context.groupId ?? event.context.target ?? "dm";

  const logPath = join(
    process.env.CLAWD_WORKSPACE ?? ".",
    "raw",
    channel,
    "chats",
    String(chatId),
    String(now.getFullYear()),
    String(now.getMonth() + 1).padStart(2, "0"),
    `${String(now.getDate()).padStart(2, "0")}.jsonl`
  );

  const dir = dirname(logPath);
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true });

  appendFileSync(logPath, JSON.stringify({
    ts: Date.now(),
    action: event.action,
    session: event.sessionKey,
    ...event.context,
  }) + "\n");
}
```

---

## step 4: add CLAWD_WORKSPACE to systemd

```bash
# add variable
echo 'Environment=CLAWD_WORKSPACE=/home/moltbot/clawd' >> ~/.config/systemd/user/moltbot.service

# or edit manually
nano ~/.config/systemd/user/moltbot.service
# add: Environment=CLAWD_WORKSPACE=/home/moltbot/clawd

# reload and restart
systemctl --user daemon-reload
systemctl --user restart moltbot
```

---

## step 5: verify

```bash
# bot status
systemctl --user status moltbot

# hook registered?
journalctl --user -u moltbot --since '5 minutes ago' | grep 'Registered hook'
# expected: Registered hook: memory-logger -> message:received, message:sent

# send message to bot in telegram, then:
find ~/clawd/raw -name "*.jsonl" -exec tail -1 {} \;
```

**example output:**
```json
{"ts":1770291848402,"action":"received","session":"agent:main:main","rawBody":"hello","senderId":"123456","senderName":"User","channel":"telegram"}
```

---

## log format

**path:** `raw/<channel>/chats/<chat_id>/YYYY/MM/DD.jsonl`

**entry structure (received):**
```json
{
  "ts": 1770291848402,
  "action": "received",
  "session": "agent:main:main",
  "message": "[formatted context]",
  "rawBody": "user message text",
  "senderId": "123456",
  "senderName": "User",
  "channel": "telegram",
  "messageId": "789",
  "isGroup": false,
  "timestamp": 1770291848000
}
```

**entry structure (sent):**
```json
{
  "ts": 1770291855000,
  "action": "sent",
  "session": "agent:main:main",
  "text": "bot response text",
  "target": "123456",
  "channel": "telegram",
  "kind": "final"
}
```

---

## known issues

### cfg.hooks = undefined

config loader in openclaw v2026.2.3 doesn't pass `hooks.internal.enabled` to `loadInternalHooks`. patch contains temporary workaround that always enables hooks discovery.

---

## troubleshooting

### hook not registering

```bash
# 1. HOOK.md exists with proper metadata?
cat ~/clawd/hooks/memory-logger/HOOK.md

# 2. package.json with type: module?
cat ~/clawd/hooks/memory-logger/package.json

# 3. workspace correct?
grep workspace ~/.openclaw/openclaw.json
# should be: "workspace": "/home/moltbot/clawd"
```

### logs not writing

```bash
# 1. CLAWD_WORKSPACE set?
cat /proc/$(pgrep -f 'openclaw$' | head -1)/environ | tr '\0' '\n' | grep CLAWD

# 2. check where it writes
find ~ -name "*.jsonl" -mmin -10
```

### build errors (OOM)

```bash
systemctl --user stop moltbot
rm -rf ~/moltbot-src/node_modules ~/moltbot-src/dist
pnpm install
NODE_OPTIONS='--max-old-space-size=2048' pnpm build
```

### rollback

```bash
cd ~/moltbot-src
git checkout .
pnpm build
systemctl --user restart moltbot
```

---

## architecture

```
telegram message
      │
      ▼
message:received hook ──→ memory-logger ──→ raw/telegram/chats/<id>/YYYY/MM/DD.jsonl
      │
      ▼
   agent processing
      │
      ▼
message:sent hook ──→ memory-logger ──→ raw/telegram/chats/<id>/YYYY/MM/DD.jsonl
      │
      ▼
telegram reply
```

**levin-inspired:** raw log = canonical truth, survives agent compaction, identity outside substrate.
