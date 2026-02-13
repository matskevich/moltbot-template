# Second Brain Implementation Plan

*practical roadmap from raw log to working second brain*

---

## security philosophy

```
minimal viable second brain:
raw log + embeddings + goal-based retrieval

graphs, atoms, extraction = later optimization
```

**principle:** каждый phase должен давать value сам по себе.

---

## current state (2026-02-08)

```
✅ raw log (message-hooks, moltbot 2026.2.3)
   - message:received → ~/clawd/raw/telegram/chats/<id>/YYYY/MM/DD.jsonl
   - message:sent → same path
   - 272KB, 127+ messages (Feb 5-8)
   - canonical truth layer WORKING

✅ embeddings (gemini-embedding-001)
   - provider: gemini, model: gemini-embedding-001
   - hybrid search: 70% vector + 30% keyword
   - 77MB sqlite DB
   - raw/ indexed via extraPaths: ["raw"]
   - raw-indexed/ auto-generated (.md) → also indexed

✅ bot self-write
   - custom/learnings.md (41KB, append-only)
   - custom/self-notes.md (20KB, append-only)

⚠️ context views (stale)
   - context/active.md — data from Feb 5 only
   - context/daily/ — 2 files (Feb 5-6), then stopped

❌ goal routing (skill exists, empty)
❌ auto-digest (not running)
❌ learnings rotation (41KB, no archival)
```

---

## Phase 1: Embeddings (FOUNDATION)

**goal:** semantic search over raw log

**why first:**
- enables "find similar" without keywords
- base for all retrieval
- no extraction needed (works on raw text)

### tasks

1. **enable memorySearch in config** ✅ DONE
```json
{
  "memorySearch": {
    "provider": "gemini",
    "model": "gemini-embedding-001",
    "sources": ["memory", "sessions"],
    "extraPaths": ["raw"],
    "query": {
      "hybrid": { "enabled": true, "vectorWeight": 0.7, "textWeight": 0.3 }
    },
    "cache": { "enabled": true, "maxEntries": 50000 },
    "sync": { "onSessionStart": true, "onSearch": true, "watch": true }
  }
}
```
config path: `agents.defaults.memorySearch`

2. **index raw/ directory** ✅ DONE
   - `extraPaths: ["raw"]` → indexes ~/clawd/raw/
   - openclaw auto-generates raw-indexed/ (.md files) for embedding search

3. **test semantic search** ⬜ TODO
```
query: "когда обсуждали левина"
→ verify memory_search returns relevant results
```

### deliverable
- `memory_search("topic")` returns relevant raw entries ✅ configured
- need to verify search quality in practice

### effort: low ✅ done
### value: high (unlocks all retrieval) ✅ foundation working

---

## Phase 2: Goal Detection (FOCUS)

**goal:** detect user intent, bias retrieval

**why second:**
- embeddings alone return "similar"
- goal detection returns "relevant for task"

### model

```
user message
     ↓
goal detector (simple regex or LLM-light)
     ↓
retrieval bias config
     ↓
filtered/weighted search
```

### implementation

```typescript
// goal-detector.ts

type Goal = 'write' | 'recall' | 'technical' | 'emotional' | 'general';

function detectGoal(message: string): Goal {
  if (/пост|напиши|tweet|текст/i.test(message)) return 'write';
  if (/помнишь|кто такой|когда мы/i.test(message)) return 'recall';
  if (/код|баг|ошибка|как сделать/i.test(message)) return 'technical';
  if (/устал|стресс|тяжело|грустно/i.test(message)) return 'emotional';
  return 'general';
}

const retrievalBias: Record<Goal, RetrievalConfig> = {
  write: {
    sources: ['memory/posts', 'custom/style'],
    boost: ['voice', 'format'],
    limit: 10
  },
  recall: {
    sources: ['raw/', 'memory/context/people'],
    boost: ['names', 'events'],
    limit: 20
  },
  technical: {
    sources: ['custom/learnings', 'custom/decisions'],
    boost: ['code', 'error'],
    limit: 15
  },
  emotional: {
    sources: ['custom/self-notes', 'memory/journal'],
    boost: ['feeling', 'coping'],
    limit: 10
  },
  general: {
    sources: ['memory'],
    boost: [],
    limit: 10
  }
};
```

### integration

option A: skill that runs on message:received
option B: hook that adds metadata to context
option C: instruction in AGENTS.md

### deliverable
- goal detected per message
- retrieval biased by goal
- agent sees relevant context

### effort: medium
### value: high (focus layer working)

---

## Phase 3: Auto-Digest (UFC LAYER)

**goal:** raw → daily summaries → structured context

**why third:**
- raw is verbose (every message)
- agent needs digestible format
- daily digest = reconstructed view

### model

```
raw/2026/02/05.jsonl (100 messages)
           ↓
     digest skill (nightly)
           ↓
context/daily/2026-02-05.md (summary)
```

### output format

```markdown
# 2026-02-05

## topics
- message-hooks implementation (technical)
- second brain architecture (planning)

## decisions
- raw log = canonical truth
- graphs not needed at base level

## people mentioned
- petya (startup update)

## open threads
- embeddings setup pending

## mood: focused, productive
```

### implementation

```typescript
// skills/auto-digest/handler.ts

export default async function digest(ctx) {
  const today = new Date().toISOString().split('T')[0];
  const rawPath = `raw/telegram/chats/*/${today.replace(/-/g, '/')}.jsonl`;

  const entries = await readRawEntries(rawPath);

  const summary = await llm.generate({
    prompt: `
      Analyze these conversation entries and extract:
      - main topics discussed
      - decisions made
      - people mentioned with context
      - open questions/threads
      - overall mood

      Be concise. Use bullet points.
    `,
    context: entries
  });

  await writeFile(`memory/context/daily/${today}.md`, summary);
}
```

### trigger

- cron: 23:00 daily
- or: hook into night-review skill

### deliverable
- daily markdown digest
- agent can read recent context fast
- searchable summaries

### effort: medium
### value: high (UFC layer started)

---

## Phase 4: People Memory (ENTITIES)

**goal:** extract and maintain facts about people

**why fourth:**
- common retrieval pattern: "who is X"
- structured better than raw search
- builds on digest infrastructure

### model

```
raw entries mentioning "petya"
           ↓
     people extractor
           ↓
memory/context/people/petya.md
```

### output format

```markdown
# petya

## facts
- 2026-02: launched startup
- 2026-01: works in fintech
- interested in AI

## relationship
- friend, met through X

## last contact
2026-02-05

## source messages
- raw/telegram/.../2026/02/05.jsonl:42
- raw/telegram/.../2026/01/15.jsonl:18
```

### implementation

- extract from daily digest (already has "people mentioned")
- or separate skill that scans raw for names
- update incrementally (append facts)

### deliverable
- structured people profiles
- fast answer to "who is X"
- relationship context

### effort: medium
### value: medium-high

---

## Phase 5: Stress-Based Expansion (ADAPTIVE)

**goal:** expand search when uncertain

**why fifth:**
- normal: narrow focused retrieval
- uncertain: broader search
- levin's stress signal concept

### model

```
agent response contains:
- "не уверен"
- "не помню"
- question back to user

     ↓

expand retrieval:
- more sources
- deeper history
- related topics
```

### implementation

```typescript
// in retrieval layer

if (detectUncertainty(agentDraft)) {
  config.limit *= 2;
  config.sources = [...config.sources, ...extendedSources];
  // re-retrieve and regenerate
}
```

### deliverable
- automatic expansion on uncertainty
- fewer "I don't know" when info exists
- adaptive retrieval radius

### effort: low-medium
### value: medium

---

## Phase 6: Analytics (META)

**goal:** patterns from raw log

**why sixth:**
- nice to have, not critical
- insights about usage
- self-optimization data

### metrics

- messages per day/hour
- topics distribution
- response patterns
- sentiment over time

### output

```markdown
# analytics: 2026-02 week 1

## activity
- 127 messages (↑12% vs last week)
- peak hours: 10-12, 21-23

## topics
- technical: 45%
- planning: 30%
- personal: 25%

## patterns
- longer conversations on weekends
- technical topics mostly morning
```

### effort: medium
### value: low-medium (optimization, not core)

---

## NOT in base plan

### graphs / zettelkasten

**why not:**
- embeddings cover 80% of retrieval needs
- graphs require extraction (LLM cost, errors)
- maintenance overhead
- можно добавить позже как optimization

**when to add:**
- if embedding search insufficient
- if explicit relationships needed
- if emergence patterns valuable

### real-time extraction

**why not:**
- adds latency to every message
- extraction errors accumulate
- batch (nightly) is enough

---

## implementation order

```
Phase 1: embeddings     ████████████████████ (foundation)
Phase 2: goal detection ████████████████     (focus)
Phase 3: auto-digest    ████████████         (UFC)
Phase 4: people memory  ████████             (entities)
Phase 5: stress expand  ██████               (adaptive)
Phase 6: analytics      ████                 (meta)
```

### minimal viable second brain

phases 1-3 = working second brain

```
raw log (done) + embeddings + goal detection + daily digest
= never forgets + focuses by goal
```

---

## next action

**Phase 2: goal detection**

phase 1 done. next:
1. implement goal-router skill (regex MVP)
2. test: разные запросы → разный retrieval bias
3. measure: does biased search improve relevance?

параллельно:
- fix context/active.md staleness (night-review skill?)
- learnings.md rotation (>20KB → archive old)
