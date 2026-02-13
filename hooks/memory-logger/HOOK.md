# memory-logger

writes all messages to raw log (layer 1 of ufc architecture).

## events

- `message:received` — incoming message before agent processing
- `message:preprocessed` — after media understanding (transcripts, image descriptions)
- `message:sent` — outgoing message after delivery

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
