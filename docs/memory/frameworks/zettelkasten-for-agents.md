# Zettelkasten for AI Agents

*atomic notes + bidirectional links для машинной памяти*

**source:** Niklas Luhmann's note-taking system

---

## original concept

Luhmann написал 70+ книг используя картотеку из 90,000 карточек.

принципы:
1. **atomic** — одна идея на карточку
2. **linked** — карточки ссылаются друг на друга
3. **emergent** — структура возникает из связей, не из иерархии

```
[card-123]                    [card-456]
"memory is reconstruction" ──→ "levin: distributed cognition"
         │                              │
         ↓                              ↓
[card-789]                    [card-012]
"raw log = source of truth"   "identity outside substrate"
```

---

## почему это работает

### традиционная иерархия:

```
topics/
├── memory/
│   ├── types/
│   │   ├── episodic.md
│   │   └── semantic.md
│   └── theories/
│       └── levin.md
```

проблема: где положить "levin on episodic memory"?

### zettelkasten:

```
notes/
├── 202602051423-memory-reconstruction.md
├── 202602051424-levin-distributed-cognition.md
├── 202602051425-raw-log-source-of-truth.md
└── 202602051426-episodic-vs-semantic.md
```

каждая заметка линкует релевантные:
```markdown
# memory is reconstruction

память не "достаёт" готовое — она реконструирует.

links:
- [[202602051424-levin-distributed-cognition]] — теоретическая база
- [[202602051425-raw-log-source-of-truth]] — практическое применение
```

---

## адаптация для AI-агента

### atomic facts from conversations

raw log entry:
```json
{"ts": 1770310643, "action": "received", "rawBody": "виделся с петей, он запустил стартап"}
```

extracted atoms:
```markdown
# fact-20260205-petya-startup

Петя запустил стартап.

source: conversation 2026-02-05
related: [[person-petya]], [[topic-startups]]
```

### auto-linking через embeddings

```
new fact: "петя получил инвестиции"
         ↓
embedding search: similar facts?
         ↓
found: "петя запустил стартап" (0.89 similarity)
         ↓
auto-link: [[fact-petya-startup]]
```

---

## структура для агента

```
memory/
├── atoms/                    # atomic facts
│   ├── fact-*.md
│   ├── person-*.md
│   └── decision-*.md
├── links.json                # graph of connections
└── index/
    └── embeddings.db         # for similarity search
```

### atom format

```markdown
---
id: fact-20260205-1423
type: fact
created: 2026-02-05T14:23:00
source: raw/telegram/chats/<USER_ID>/2026/02/05.jsonl:42
tags: [petya, startup, news]
---

# Петя запустил стартап

Из разговора: "виделся с петей, он запустил стартап"

## links
- [[person-petya]] — о ком
- [[topic-startups]] — тема
```

---

## retrieval через graph

запрос: "что я знаю о пете?"

```
start: [[person-petya]]
         ↓
traverse links:
  → [[fact-petya-startup]]
  → [[fact-petya-investment]]
  → [[conversation-20260205-petya]]
         ↓
aggregate: все связанные факты
```

**не keyword search** — а graph traversal.

---

## emergence

через накопление atoms и links:
- возникают clusters (темы)
- видны patterns (что часто обсуждаем)
- появляются gaps (о чём не знаем)

```
graph analysis:

cluster: [startup, petya, investment, pitch]
  → "много обсуждаем петин стартап"

orphan: [random-fact-xyz]
  → "изолированный факт, нет связей"

bridge: [levin, memory, startups]
  → "неожиданная связь между темами"
```

---

## сравнение с raw log

| aspect | raw log | zettelkasten |
|--------|---------|--------------|
| granularity | message | atomic fact |
| structure | chronological | graph |
| retrieval | time-based, search | link traversal |
| emergence | нет | да |
| effort | zero (automatic) | extraction needed |

**комбинация:**

```
raw log (layer 1)
     ↓
fact extraction (automated)
     ↓
zettelkasten atoms (layer 2)
     ↓
graph-based retrieval
```

---

## implementation sketch

### 1. fact extractor skill

```typescript
// trigger: daily or on raw log update
async function extractFacts(rawEntries) {
  for (const entry of rawEntries) {
    const facts = await llm.extract(entry.rawBody, {
      prompt: "extract atomic facts, people mentioned, decisions made"
    });

    for (const fact of facts) {
      await createAtom(fact);
      await findAndLink(fact); // embedding similarity
    }
  }
}
```

### 2. link graph

```json
{
  "fact-20260205-1423": {
    "links": ["person-petya", "topic-startups"],
    "backlinks": ["conversation-20260205"]
  }
}
```

### 3. graph retrieval

```typescript
function retrieve(query, depth = 2) {
  const startNodes = embeddingSearch(query);
  const visited = new Set();
  const result = [];

  function traverse(node, d) {
    if (d > depth || visited.has(node)) return;
    visited.add(node);
    result.push(readAtom(node));

    for (const link of getLinks(node)) {
      traverse(link, d + 1);
    }
  }

  for (const node of startNodes) {
    traverse(node, 0);
  }

  return result;
}
```

---

## что взять

1. **atomic facts** — granular > monolithic
2. **bidirectional links** — context через связи
3. **emergence from graph** — patterns видны
4. **source tracking** — откуда факт

---

## challenges

1. **extraction quality** — LLM может ошибаться
2. **link maintenance** — граф может запутаться
3. **overhead** — больше processing чем raw log

**решение:** zettelkasten как optional layer над raw log.
raw = guaranteed truth, atoms = extracted insights.

---

*structure emerges from connections, not from hierarchy*
