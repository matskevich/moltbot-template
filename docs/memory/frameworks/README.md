# Memory Frameworks Collection

*разные подходы к памяти для AI-агентов*

---

## frameworks

| framework | core idea | status |
|-----------|-----------|--------|
| [Levin: Cognitive Light Cone](levin-cognitive-light-cone.md) | distributed cognition, memory as infrastructure | теоретическая база |
| [MemGPT](memgpt.md) | hierarchical memory, agent-controlled | reference |
| [Zettelkasten](zettelkasten-for-agents.md) | atomic notes, graph-based retrieval | research |

---

## TODO: добавить

- [ ] **Reflexion** — self-reflection loops, learn from mistakes
- [ ] **Generative Agents (Stanford)** — memory stream + reflection + planning
- [ ] **RETRO** — retrieval-augmented generation
- [ ] **RAG patterns** — chunking strategies, hybrid search
- [ ] **Personal.ai** — commercial memory layer approach
- [ ] **Mem0** — memory layer for LLM apps

---

## comparison matrix

| aspect | Levin | MemGPT | Zettelkasten | Our approach |
|--------|-------|--------|--------------|--------------|
| storage | distributed | vector DB | graph | jsonl + vectors |
| control | infrastructure | agent | manual + auto | infrastructure |
| retrieval | goal-based | query-based | link traversal | goal-biased |
| guaranteed? | yes | no | no | yes |
| atomic unit | event | memory object | note | message |

---

## synthesis: our approach

берём лучшее:

```
Levin:        memory as infrastructure (not agent function)
MemGPT:       hierarchical tiers (core/recall/archival)
Zettelkasten: atomic facts + links (emergence)
```

результат:

```
Layer 1: raw log (guaranteed, chronological)
Layer 2: extracted atoms (facts, people, decisions)
Layer 3: UFC views (goal-reconstructed)
```

---

## почему hooks, не cron

**cron не работает:**
compaction срабатывает каждые несколько сообщений. агент решает на лету что "важно" и выкидывает остальное. к моменту cron — оригиналы уже summarized или удалены. логируешь огрызки, не данные.

**hooks работают:**
срабатывают В МОМЕНТ сообщения, ДО обработки. raw сохраняется параллельно, агент делает что хочет со своей копией. два независимых потока: архив (полный, гарантированный) и рабочая память (компактная, lossy).

**архитектура:**
```
message ──→ hook fires ──→ raw/ (verbatim)
                │
                ↓ (parallel)
          agent processing
          compaction
          working memory
                │
                ↓
          agent forgets details
          (but raw/ has everything)
```

**ночной pass:**
```
raw/ ──→ UFC goal-directed retrieval ──→ тематические .md файлы ──→ embeddings
```

принцип: не доверяй агенту решать что важно в момент сообщения. у него нет полной картины и нет твоих будущих целей. логируй всё, извлекай по целям позже

---

## adding new frameworks

формат:
```markdown
# Framework Name

*one-line description*

**source:** link

## core concept
## architecture
## comparison with our approach
## what to take
## limitations
```

---

*collect patterns, synthesize approach*
