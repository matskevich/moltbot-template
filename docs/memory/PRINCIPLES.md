# Second Brain: Core Principles

*mental models chain — ideas → consequences → effects*

---

## problem

1. agent = temporary process
2. memory inside agent = amnesia on reset
3. "second brain" at this level = impossible

**conclusion:**
while agent = source of truth, memory does not exist

---

## key shift

```
memory ≠ agent behavior
memory = infrastructure

agent must READ memory
not OWN it
```

---

## model 1: reality layer (raw)

raw = what actually happened

- append-only
- no interpretations
- survives any reset

**invariant:**
if event not in raw — it didn't happen

---

## model 2: reconstruction layer (UFC)

UFC = goal-specific view of raw

- generated from raw on demand
- different views for different goals
- can be regenerated anytime

**invariant:**
UFC without raw = hallucination

---

## model 3: focus layer (retrieval)

focus = what agent sees right now

- not everything — relevant subset
- goal determines relevance
- changes per task

**invariant:**
focus without UFC = random

---

## dependency chain

```
raw → UFC → focus → agent

break any link — second brain breaks
```

---

## long-term alignment

alignment = overlay over raw

- goals = data
- weekly = reconstruction
- deviations = comparison

**invariant:**
alignment is a process, not agent state

---

## main consequence

before:
> "is he in context right now?"

now:
> "context can be reconstructed"

---

## effects

- can trust (raw doesn't lie)
- can plan for months (persistence)
- can change models (identity in raw, not agent)
- can reconstruct meaning (from raw anytime)
- can build real second brain

---

## one line

> **second brain = system that never forgets and can focus by goal**

---

## corollaries

### identity

identity lives in raw, not in agent.
agent is interface, raw is self.

### trust

trust = f(raw completeness).
more raw → more trust.

### planning horizon

without raw: planning horizon = context window
with raw: planning horizon = unlimited

### model independence

change claude-3 → claude-4 → claude-5
raw stays. identity stays.

### failure recovery

agent crashes? restart, read raw, continue.
no loss.

---

## anti-patterns

| pattern | why broken |
|---------|------------|
| agent decides what to save | single point of failure |
| memory = summary | lossy, interpretation |
| context = truth | dies on reset |
| goals in agent head | forgotten on compaction |

---

## design principles

1. **raw first** — capture everything, filter later
2. **infrastructure owns memory** — agent consumes
3. **goals as data** — not agent state
4. **reconstruction > storage** — UFC from raw
5. **focus by goal** — not random retrieval

---

*memory is infrastructure. agent is interface. identity is pattern in raw.*
