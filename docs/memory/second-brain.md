# second brain architecture

*inspired by michael levin's cognitive light cone*

living execution plan: `second-brain-plan.md`

## core insight

memory ≠ static database
memory = **adaptive agent** that retrieves differently based on goal

levin: keeping everything in head = narrowing cognitive light cone
second brain = **redistribution** of cognitive load across system

---

## architecture

```
┌─────────────────────────────────────────────────────┐
│                    GOAL DETECTOR                     │
│         (what is user trying to do right now?)       │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│              RETRIEVAL STRATEGY ROUTER               │
│                                                      │
│  goal: "write post"    → bias: style, voice, topics │
│  goal: "process stress"→ bias: journal, coping      │
│  goal: "solve technical"→ bias: code, decisions     │
│  goal: "remember person"→ bias: interactions, facts │
└─────────────────────┬───────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│                 RAW LOG (layer 1)                    │
│                                                      │
│  append-only jsonl, every event, no decisions       │
│  raw/<channel>/chats/<id>/YYYY/MM/DD.jsonl          │
└─────────────────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────┐
│              UFC CONTEXT (layer 2)                   │
│                                                      │
│  goal-specific reconstruction from raw              │
│  markdown summaries, agent reads only this          │
│                                                      │
│  DYNAMIC: different "views" per goal                │
└─────────────────────────────────────────────────────┘
```

---

## implementation phases

### phase 1: raw capture (NOW — message-hooks patch)

```
message:received → append to raw log
message:sent → append to raw log
```

всё пишется, ничего не теряется.

**почему hooks, не cron:** compaction срабатывает каждые несколько сообщений — агент на лету решает "что важно", остальное выкидывает. к cron оригиналы уже огрызки. hooks срабатывают ДО обработки, параллельно агенту. два потока: raw (полный архив, гарантированный) + working memory (lossy). принцип: не доверяй агенту решать что важно — у него нет твоих будущих целей. логируй всё, извлекай по целям позже.

### phase 2: goal detection (SIMPLE)

```typescript
// в SOUL.md или skill
function detectGoal(message: string): Goal {
  if (/пост|tweet|написать/i.test(message)) return 'write';
  if (/стресс|тяжело|устал/i.test(message)) return 'stress';
  if (/код|баг|ошибка/i.test(message)) return 'technical';
  if (/кто такой|помнишь/i.test(message)) return 'recall';
  return 'general';
}
```

### phase 3: retrieval bias (via memorySearch)

```typescript
const retrievalConfig = {
  write: {
    sources: ['memory/posts', 'memory/style'],
    boost: ['voice', 'topics']
  },
  stress: {
    sources: ['memory/journal', 'memory/coping'],
    boost: ['emotional', 'support']
  },
  technical: {
    sources: ['memory/decisions', 'memory/learnings', 'custom'],
    boost: ['code', 'architecture']
  }
};
```

### phase 4: dynamic ufc generation

raw → goal-specific markdown view
(не статичный summary, а reconstruction под задачу)

---

## что реализуемо сейчас

### 1. raw log (message-hooks patch)
- другой агент делает backport
- memory-logger hook готов

### 2. simple goal routing (skill)

```typescript
// skills/goal-router/handler.ts
export default async function(ctx) {
  const goal = detectGoal(ctx.message);

  // добавить в context для агента
  ctx.metadata.currentGoal = goal;
  ctx.metadata.retrievalBias = retrievalConfig[goal];

  // агент видит это и retrieves соответственно
}
```

### 3. structured memory directories

```
memory/
├── posts/       # написанное (для write goal)
├── journal/     # личное (для stress goal)
├── decisions/   # технические решения
├── learnings/   # выводы из ошибок
├── people/      # facts about people
└── style/       # voice, patterns
```

---

## связь с патчем

```
message-hooks patch
       │
       ▼
memory-logger hook → writes to raw/
       │
       ▼
goal-router skill → detects goal, sets bias
       │
       ▼
agent reads ufc with bias → better retrieval
```

---

## levin framing

- raw log = long-term memory (hippocampus equivalent)
- ufc context = working memory (goal-reconstructed)
- goal detector = attention mechanism
- retrieval bias = cognitive light cone shaping

**система думает распределённо**: human + bot + raw + retrieval = один когнитивный агент

memory becomes infrastructure, not agent responsibility.
