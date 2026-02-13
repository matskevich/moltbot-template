---
name: memory-logger
description: "Write all messages to raw log (layer 1 of ufc architecture)"
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

writes all messages to raw log (layer 1 of ufc architecture).

## output

```
raw/<channel>/chats/<id>/YYYY/MM/DD.jsonl
```

each line = json record:
```json
{"ts":1707123456789,"action":"received","session":"...","message":"hello","senderId":"123"}
```

## why

memory as infrastructure, not agent responsibility.
agent can die (compaction) and reconstruct from raw log.
