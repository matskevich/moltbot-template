# Memory Management Research

*исследование архитектур памяти для AI-агентов*

second brain execution plan: `second-brain-plan.md`

---

## проблема

AI-агенты страдают **когнитивной амнезией**:

```
понедельник: объяснил контекст, агент понял, работали отлично
вторник: compaction → "напомни кто ты?"
```

причины:
- context window ограничен
- compaction стирает "неважное" (по мнению агента)
- память внутри агента = single point of failure
- агент сам решает что помнить → субъективно, ненадёжно

**результат:** каждая сессия — с чистого листа. нет continuity.

---

## решение: Second Brain

память вне агента. агент — потребитель, не владелец.

```
традиционно:              second brain:

user → agent → memory     user → agent
       ↑_____|                    ↓
       сам решает         raw log (infrastructure)
       что помнить               ↓
                          retrieval layer
                                 ↓
                          agent reads context
```

**ключевой сдвиг:** память как инфраструктура, не как функция агента.

---

## как raw log разблокирует Second Brain

### до message-hooks

```
user message → agent processes → agent decides what to remember → maybe saves
                                        ↑
                               single point of failure
```

проблемы:
- агент может забыть сохранить
- compaction может удалить
- нет гарантии что что-то записано
- нельзя восстановить что было

### после message-hooks

```
user message → hook:received → RAW LOG (guaranteed)
                    ↓
              agent processes
                    ↓
              hook:sent → RAW LOG (guaranteed)
```

**гарантии:**
- каждое сообщение записано (независимо от агента)
- append-only (ничего не удаляется)
- можно восстановить любой разговор
- агент может упасть, забыть, сломаться — raw log выживает

---

## second brain architecture (из second-brain.md)

```
GOAL DETECTOR  ──▶  RETRIEVAL ROUTER  ──▶  RAW LOG (layer 1)  ──▶  UFC CONTEXT (layer 2)
```

- **goal detector** — skill/промпт понимает задачу пользователя сейчас
- **retrieval router** — выбирает источники/веса (style vs journal vs decisions)
- **raw log** — append-only (message-hooks + memory-logger)
- **UFC context** — goal-specific reconstruction (markdown, summaries, facts)

Эта цепочка разворачивает "second brain": память вне агента, goal-aware, адаптивная. Подробно см. `second-brain.md`.

---

## архитектура: два слоя

### Layer 1: Raw Log (canonical truth)

```
raw/
├── telegram/
│   └── chats/
│       └── <USER_ID>/
│           └── 2026/02/05.jsonl
```

характеристики:
- append-only jsonl
- каждое сообщение = одна строка
- timestamp, sender, text, channel
- никакой интерпретации, только факты
- никогда не редактируется

**аналогия:** hippocampus — долгосрочная память, сырые события

### Layer 2: UFC (goal-reconstructed views)

```
context/
├── active.md          # текущие темы
├── daily/
│   └── 2026-02-05.md  # digest дня
└── people/
    └── petya.md       # факты о человеке
```

характеристики:
- генерируется из raw/
- разные "views" под разные задачи
- агент читает только это
- можно перегенерировать из raw/

**аналогия:** working memory — goal-specific reconstruction

---

## Goal-Based Retrieval

разные задачи требуют разный контекст:

| goal | retrieval bias |
|------|----------------|
| "пишу пост" | style/, posts/, voice patterns |
| "стресс" | journal/, coping, self-notes |
| "technical" | learnings/, decisions/, code |
| "вспомни X" | people/, interactions |

```
user: "помоги написать пост"
       ↓
goal detector: "write"
       ↓
retrieval router: bias → style/, posts/
       ↓
agent gets relevant context (not everything)
```

**levin framing:** это cognitive light cone — расширяем или сужаем область внимания под задачу.

---

## что это даёт

### 1. identity continuity

агент может забыть, сломаться, быть заменён.
raw log остаётся. identity вне substrate.

```
agent v1 умер → agent v2 читает raw log → continuity
```

### 2. audit trail

всё что было сказано — записано.
можно найти "когда мы обсуждали X".

### 3. autonomous skills

skills могут работать без агента:
- ночной digest (читает raw/, пишет summary)
- people extractor (парсит raw/, обновляет people/)
- analytics (patterns из raw/)

### 4. recovery

context потерян? восстанови из raw/:
```
raw/2026/02/*.jsonl → reconstruct → context/
```

### 5. multi-agent

несколько агентов могут читать один raw log:
- main agent (conversation)
- research agent (deep work)
- review agent (daily summary)

---

## implementation status (2026-02-08)

```
✅ raw log          — message-hooks working (272KB, Feb 5-8)
                      path: ~/clawd/raw/telegram/chats/<id>/YYYY/MM/DD.jsonl
✅ embeddings       — gemini-embedding-001, hybrid 70/30, 77MB DB
                      raw/ indexed via extraPaths, raw-indexed/ auto-generated
⚠️ auto-digest      — context/daily/ has 2 files (Feb 5-6), then stopped
                      night-review skill exists but needs verification
❌ people memory    — not started
❌ goal routing     — skill exists but empty
❌ analytics        — not started
```

---

## frameworks (research)

см. `frameworks/` для разных подходов:

- `levin-cognitive-light-cone.md` — теоретическая база
- `zettelkasten-for-agents.md` — atomic notes
- `memgpt.md` — hierarchical memory
- `reflexion.md` — self-reflection loops

---

## related

- `second-brain.md` — original design doc
- `second-brain-plan.md` — execution plan (живой)

---

*memory is infrastructure, not agent responsibility*
