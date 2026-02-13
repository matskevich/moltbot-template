# message-hooks: raw log for openclaw bots

patch adds `message:received` and `message:sent` hook events.
every message (in + out) gets logged to jsonl files.

**tested on:** openclaw v2026.2.3+ (stable), v2026.2.6-3

---

## what's in the box

```
message-hooks.patch   — patch for openclaw source
hook/
  handler.ts          — memory-logger hook (writes jsonl)
  HOOK.md             — hook metadata (openclaw discovers this)
  package.json        — esm marker
```

---

## install (5 steps)

### 1. apply patch

```bash
cd ~/your-openclaw-src
git apply /path/to/message-hooks.patch

# if conflicts:
git apply --3way /path/to/message-hooks.patch
```

verify:
```bash
grep -r "triggerMessageReceived" src/
# should find: dispatch.ts, message-hooks.ts, bot-message-dispatch.ts
```

### 2. build

```bash
# stop bot first (frees RAM for build)
systemctl --user stop yourbot

pnpm install
NODE_OPTIONS='--max-old-space-size=2048' pnpm build
```

### 3. copy hook

```bash
# replace ~/clawd with your workspace path
cp -r hook/ ~/clawd/hooks/memory-logger/
```

### 4. add CLAWD_WORKSPACE to systemd

your bot's systemd unit needs:
```ini
Environment=CLAWD_WORKSPACE=/home/youruser/clawd
```

then:
```bash
systemctl --user daemon-reload
systemctl --user start yourbot
```

### 5. verify

```bash
# send a message to your bot in telegram, then:
find ~/clawd/raw -name "*.jsonl" -mmin -5
# should find at least one file

# check both directions:
tail -5 $(find ~/clawd/raw -name "*.jsonl" -mmin -5 | head -1)
# should see action:"received" and action:"sent"
```

---

## log format

**path:** `raw/<channel>/chats/<chat_id>/YYYY/MM/DD.jsonl`

**received:**
```json
{"ts":1770291848402,"action":"received","session":"agent:main:main","rawBody":"hello","senderId":"123456","senderName":"User","channel":"telegram","isGroup":false}
```

**sent:**
```json
{"ts":1770291855000,"action":"sent","session":"agent:main:main","text":"bot response","target":"123456","channel":"telegram","kind":"final","isGroup":false}
```

group messages include `"isGroup":true,"groupId":"-100XXXXXXXXXX"`.

---

## troubleshooting

**hook not loading:**
- check `HOOK.md` exists with proper yaml frontmatter
- check `package.json` has `{"type": "module"}`
- check workspace path matches systemd `CLAWD_WORKSPACE`

**logs not writing:**
```bash
# is CLAWD_WORKSPACE set in the process?
cat /proc/$(pgrep -f 'openclaw$' | head -1)/environ | tr '\0' '\n' | grep CLAWD
```

**build OOM:**
```bash
systemctl --user stop yourbot
rm -rf node_modules dist
pnpm install
NODE_OPTIONS='--max-old-space-size=2048' pnpm build
```

**rollback:**
```bash
cd ~/your-openclaw-src
git checkout .
pnpm build
systemctl --user restart yourbot
```

---

## what you get

- canonical raw log of ALL messages (survives agent compaction)
- structured by channel/chat/date for easy lookup
- both directions (received + sent) with group context
- foundation for: semantic search, daily digests, analytics, people memory
