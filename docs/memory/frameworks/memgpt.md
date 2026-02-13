# MemGPT: Hierarchical Memory for LLMs

*virtual context management через memory hierarchy*

**source:** https://memgpt.ai / UC Berkeley research

---

## problem

LLMs имеют фиксированный context window:
- GPT-4: ~128k tokens
- Claude: ~200k tokens
- но разговоры могут быть бесконечными

**что делать когда context заполнен?**

традиционно: summarize → lose details
MemGPT: hierarchical memory + virtual context

---

## architecture

```
┌─────────────────────────────────────────┐
│           MAIN CONTEXT                   │
│      (что LLM видит прямо сейчас)        │
│                                          │
│  system prompt + recent messages +       │
│  retrieved memories + working state      │
└─────────────────────────────────────────┘
                    ↑ ↓
┌─────────────────────────────────────────┐
│         MEMORY FUNCTIONS                 │
│                                          │
│  core_memory_append()                    │
│  core_memory_replace()                   │
│  archival_memory_insert()                │
│  archival_memory_search()                │
│  conversation_search()                   │
└─────────────────────────────────────────┘
                    ↑ ↓
┌─────────────────────────────────────────┐
│         ARCHIVAL MEMORY                  │
│      (безлимитное хранилище)             │
│                                          │
│  - vector database                       │
│  - full conversation history             │
│  - facts, preferences, notes             │
└─────────────────────────────────────────┘
```

---

## memory tiers

### Tier 1: Core Memory (always in context)

```
persona: "I am an AI assistant who..."
human: "User prefers concise answers, works in tech..."
```

- всегда видно агенту
- небольшой размер (~2k tokens)
- самое важное о себе и юзере

### Tier 2: Recall Memory (conversation buffer)

- последние N сообщений
- FIFO когда переполняется
- можно искать в старых

### Tier 3: Archival Memory (unlimited)

- vector database
- полная история
- facts, documents, notes
- поиск по запросу

---

## key innovation: agent controls memory

LLM сам решает когда:
- сохранить важный факт → `archival_memory_insert()`
- найти релевантное → `archival_memory_search(query)`
- обновить core memory → `core_memory_replace()`

```python
# LLM output example:
{
  "function": "archival_memory_insert",
  "arguments": {
    "content": "User mentioned they have a meeting with John on Friday"
  }
}
```

---

## virtual context management

когда context заполняется:
1. старые сообщения уходят в archival
2. summary остаётся в recall
3. retrieval подтягивает релевантное

**иллюзия бесконечного контекста** через умное paging.

---

## сравнение с нашим подходом

| aspect | MemGPT | our approach |
|--------|--------|--------------|
| raw storage | vector DB | jsonl files |
| who decides to save | agent | hook (automatic) |
| retrieval | agent calls function | goal-based bias |
| guaranteed? | no (agent must call) | yes (infrastructure) |
| identity | in core memory | in raw log |

**ключевое отличие:**

MemGPT: агент управляет памятью (agent-centric)
Our: память существует независимо (infrastructure-centric)

---

## что взять

### 1. hierarchical tiers (да)

```
tier 1: core facts (SOUL.md, USER.md)
tier 2: recent context (last N messages)
tier 3: full history (raw/)
```

### 2. agent-controlled retrieval (частично)

agent может просить конкретное:
```
"найди когда мы обсуждали X"
```

но baseline retrieval = automatic (goal-based)

### 3. core memory concept (да)

SOUL.md = persona
USER.md = human facts

always in context, updateable

---

## limitations of MemGPT

1. **single point of failure** — agent must remember to save
2. **no guaranteed capture** — can miss important things
3. **retrieval depends on agent query** — might not ask right question

**наш подход решает это:**
- raw log captures EVERYTHING automatically
- retrieval is goal-biased, not just query-based

---

## implementation ideas

```
сombine both:

1. raw log (guaranteed capture) — our approach
2. core memory (SOUL.md, USER.md) — from MemGPT
3. archival with vectors (embeddings) — from MemGPT
4. goal-based retrieval — our approach
```

best of both worlds.

---

*MemGPT: agent manages memory. Our approach: memory exists independently, agent consumes.*
