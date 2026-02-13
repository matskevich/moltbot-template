# share pack: second brain setup

use this file to brief a friend end-to-end: patch, architecture, philosophy,
implementation, and plan. keep links public.

## 0) public links (required)

patch (message hooks):
```
openclaw PR (source):        https://github.com/openclaw/openclaw/pull/6797
lifecycle proposal:          https://github.com/openclaw/openclaw/discussions/14539
patch backport (our repo):   https://github.com/matskevich/openclaw-infra/tree/main/patches/message-hooks-pr6797
install guide:               https://github.com/matskevich/openclaw-infra/tree/main/patches/message-hooks-pr6797/INSTALL.md
results/verification:        https://github.com/matskevich/openclaw-infra/tree/main/patches/message-hooks-pr6797/RESULTS.md
```

if you only share one link, share the Discussion (it has the full story).

---

## 1) what this builds

second brain for openclaw: memory is infrastructure, not agent state.
raw log is canonical truth. retrieval is goal-biased. daily digest is working memory.

---

## 2) patch (why it matters)

message hooks add three lifecycle events: `message:received`, `message:preprocessed`, `message:sent`.
we use them to write append-only raw logs with full transcripts, independent of the model.
this prevents memory loss on compaction and enables retrieval, search, and analytics.

---

## 3) architecture (how it works)

core diagram and layers:
`docs/architecture-memory.md`
`docs/architecture/second-brain.md`
`docs/architecture-memory-consolidation.md`

### current memory stack (full description)

**layer 1: identity (persistent)**
- `SOUL.md` — voice, principles, mode
- `USER.md` — user profile, preferences, long-term context

**layer 2: philosophy (slow evolution)**
- `meta/philosophy.md`
- `meta/identity-continuity.md`
- `meta/capabilities.md`

**layer 3: learnings (append-only)**
- `custom/learnings.md` — meta lessons, mistakes → principles
- `custom/self-notes.md` — ongoing tasks, self-notes
- `custom/action-log.md` — concrete decisions/actions

**layer 4: sessions (summaries)**
- `memory/sessions/YYYY-MM-DD-summary.md` — compaction flush summaries
- `memory/consolidated/YYYY-MM-DD.md` — nightly consolidation (planned)

**layer 5: embeddings (search index)**
- `~/.openclaw/memory/main.sqlite` — embeddings DB
- hybrid search: 70% vector + 30% keyword
- provider: gemini, model: `gemini-embedding-001`

---

### write path (capture)

```
user message
  ↓
message hooks (received/preprocessed/sent)
  ↓
raw log (append-only jsonl)
  ↓
raw-indexed (.md, auto-generated)
  ↓
embeddings DB
```

**compaction flush (before context reset)**
- write session summary → `memory/sessions/`
- append tasks → `custom/self-notes.md`
- append learnings → `custom/learnings.md`

---

### read path (recall)

```
user query
  ↓
memory_search (hybrid)
  ↓
results injected into context
```

**goal bias (planned):**
retrieval sources and weights depend on detected intent
(write / recall / technical / emotional / general).

---

### file hierarchy (canonical)

```
~/clawd/
├── SOUL.md
├── USER.md
├── custom/
│   ├── learnings.md
│   ├── self-notes.md
│   └── action-log.md
├── meta/
│   ├── philosophy.md
│   ├── identity-continuity.md
│   └── capabilities.md
├── memory/
│   ├── sessions/
│   └── consolidated/
├── raw/                    # append-only jsonl (by hooks)
└── skills/

~/.openclaw/memory/
└── main.sqlite             # embeddings DB
```

---

### config (memory_search)

```
memorySearch:
  provider: gemini
  model: gemini-embedding-001
  sources: [memory, sessions]
  extraPaths: [raw]
  query:
    hybrid: { enabled: true, vectorWeight: 0.7, textWeight: 0.3 }
  cache: { enabled: true, maxEntries: 50000 }
```

---

### current state summary (as of 2026-02-12)

- raw log working (hooks → `~/clawd/raw/`, 550+ events, 7 days)
- message:preprocessed working (voice transcripts, photo descriptions in log)
- embeddings working (hybrid search, 2657 cached embeddings)
- self-write working (`custom/learnings.md`, `custom/self-notes.md`)
- output DLP working (regex + entropy scan on message:sent)
- multi-bot sync working (2 bots, 4 groups via arena-hub)
- goal router not implemented
- context/daily stale (auto-digest not running)
- people memory not started

---

## 4) philosophy and principles

memory = infrastructure, not agent responsibility.
raw log = truth. summary is a view, not ground truth.
goal-based retrieval = attention mechanism.

refs:
`docs/memory/PRINCIPLES.md`
`docs/memory/frameworks/levin-cognitive-light-cone.md`
`docs/memory/frameworks/memgpt.md`
`docs/memory/frameworks/zettelkasten-for-agents.md`

---

## 5) detailed implementation

`docs/memory/IMPLEMENTATION.md` (current state + phases + config examples)
`docs/memory/README.md` (research overview)

---

## 6) live plan

`docs/architecture/second-brain-plan.md`

---

## 7) reality check (incident)

`initiatives/infrastructure-resilience/internal/investigation.md`
`initiatives/infrastructure-resilience/internal/plan.md`

---

## 8) quick summary you can send

we patched openclaw to log every message (raw, append-only).
then we layer embeddings + goal-based retrieval + daily digest.
result: memory survives compaction, is verifiable, and adapts to goals.
open question: how far to automate consolidation without losing truth.
