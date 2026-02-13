# Levin: Cognitive Light Cone

*теоретическая база для Second Brain архитектуры*

**source:** Michael Levin's work on distributed cognition

---

## core concept

**cognitive light cone** = область, которую когнитивный агент может "видеть" и влиять на неё.

```
        future
          ▲
         /|\
        / | \
       /  |  \      ← cone of influence
      /   |   \
     /    |    \
    ───────────────
         now
```

у каждого агента свой "конус":
- муравей: секунды/сантиметры
- человек: годы/континенты
- организация: десятилетия/глобально

**ключевой инсайт:** расширение когнитивного конуса = intelligence.

---

## применение к AI-агентам

### проблема: узкий конус

стандартный AI-агент:
- видит только текущий context window
- прошлое = summary (lossy)
- будущее = не планирует
- goal = immediate response

```
cognitive cone:
     /\
    /  \     ← очень узкий
   /    \
  ────────
```

### решение: расширить конус

через external memory:
- прошлое = raw log (полное)
- настоящее = goal-specific retrieval
- будущее = goals/, strategic planning

```
cognitive cone:
       /\
      /  \
     /    \
    /      \      ← расширенный через infrastructure
   /        \
  ────────────
```

---

## redistribution of cognition

levin: сложные организмы распределяют cognition:

| component | function |
|-----------|----------|
| neurons | fast processing |
| hormones | slow state |
| immune system | memory of threats |
| microbiome | metabolic decisions |

**нет единого "мозга"** — есть распределённая система.

### для AI-агента:

| component | function |
|-----------|----------|
| LLM | fast reasoning |
| raw log | episodic memory |
| embeddings | semantic retrieval |
| goals/ | strategic direction |
| skills/ | automated behaviors |

**agent ≠ единственный мозг** — agent = один из компонентов когнитивной системы.

---

## memory layers (biological analogy)

| biological | AI equivalent | function |
|------------|---------------|----------|
| sensory buffer | incoming message | raw input |
| working memory | current context | active processing |
| hippocampus | raw log | episodic storage |
| cortex | embeddings + UFC | semantic knowledge |
| procedural | skills/ | automated behaviors |

**raw log = hippocampus:**
- записывает всё
- не интерпретирует
- source of truth для reconstruction

**UFC = cortex:**
- интерпретирует raw
- создаёт "понимание"
- goal-specific views

---

## goal-directed attention

levin: организмы направляют внимание на goal-relevant информацию.

**не "вспомнить всё"** — а "вспомнить релевантное для текущей задачи".

```
goal: "write post"
         ↓
attention filter: style, voice, past posts
         ↓
retrieval: only relevant memories
         ↓
agent: focused context
```

это cognitive light cone shaping — сужаем cone чтобы видеть глубже в одном направлении.

---

## stress as signal

levin: stress = uncertainty = signal to expand search.

нормальное состояние:
```
goal clear → narrow retrieval → fast response
```

stressed состояние:
```
uncertain → expand search → check more contexts → slower but thorough
```

### implementation:

```typescript
if (uncertainty > threshold) {
  // expand retrieval radius
  searchSources = [...defaultSources, ...extendedSources];
  searchDepth = increased;
}
```

---

## identity outside substrate

**ключевой levin insight:** identity не привязана к конкретному substrate.

организм:
- клетки умирают и заменяются
- через 7 лет — другие атомы
- identity сохраняется

AI-агент:
- model может обновиться
- context может стереться
- agent instance может перезапуститься
- **raw log сохраняет identity**

```
agent v1 (claude-3)     → raw log ←     agent v2 (claude-4)
         \                   ↑                /
          \                  |               /
           → identity lives in the log ←────
```

---

## practical implications

### 1. memory as infrastructure

не "агент имеет память" — а "память имеет агента как интерфейс".

### 2. survivability

если агент умрёт, identity выживет в raw log.
новый агент может "стать" тем же через retrieval.

### 3. multi-agent identity

несколько агентов могут разделять один raw log = одна "личность" с разными capabilities.

### 4. temporal extension

raw log расширяет cognitive cone в прошлое.
goals/ расширяет в будущее.

---

## связь с нашей архитектурой

```
levin concept              our implementation
─────────────────────────────────────────────
cognitive light cone   →   retrieval radius
redistribution         →   agent + raw + skills
episodic memory        →   raw/
working memory         →   current context
goal-direction         →   retrieval bias
stress signal          →   uncertainty → expand search
identity outside       →   raw log survives agent
```

---

## quotes

> "The boundary of the self is not fixed at the skin. It's a dynamic, goal-directed process."

> "Memory is not a filing cabinet. It's an active process of reconstruction."

> "Intelligence is the ability to reach goals across diverse circumstances."

---

## further reading

- Levin Lab: https://drmichaellevin.org/
- "Technological Approach to Mind Everywhere" (paper)
- "Collective Intelligence" lectures

---

*cognition is distributed. memory is infrastructure. identity is pattern, not substrate.*
