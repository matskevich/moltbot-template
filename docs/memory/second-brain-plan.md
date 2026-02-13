# second brain execution plan

*living plan for evolving memory, alignment, and retrieval*

## metadata

- from: owner
- to: claude-code
- date: 2026-02-09
- context: moltbot second brain evolution
- scope: memory + alignment + retrieval
- status: active (update as we go)

---

## background (current state — updated 2026-02-09)

working:
- raw log via message hooks (14 jsonl files, writes daily)
- config consolidated: single `openclaw.json` (moltbot.json deleted)
- embeddings model fixed: `gemini-embedding-001` (was broken since feb 6 due to `text-embedding-004` in shadow config)
- self-write: `custom/learnings.md` (111 lines), `custom/self-notes.md` (615 lines)
- nightly-synthesis runs, updates `alignment.yaml`
- goals/ structure deployed with 3 temporal lenses (immediate/weekly/strategic)

broken/missing:
- embeddings DB does not exist yet (model was wrong, now fixed, awaiting first search)
- `context/daily/*` is stale
- goal routing not implemented (SKILL.md exists, no code)
- people memory not started
- `USER.md` mostly placeholders

source docs:
`architecture-memory.md`
`docs/memory/IMPLEMENTATION.md`
`second-brain.md`
`architecture-memory-consolidation.md`

---

## intent

turn memory into infrastructure that survives compaction and supports long-term alignment.
focus on minimal changes that unlock high leverage:
goal-biased retrieval + daily digest + explicit goals as data.

---

## principles (do not violate)

- memory is infrastructure, not agent responsibility
- raw log is canonical truth
- identity continuity is file-based (SOUL.md, USER.md, memory files)
- avoid heavy extraction up front; prefer lightweight, incremental steps

---

## targets

1. make goals explicit as data
2. implement goal routing and retrieval bias
3. restore daily digest (UFC context)
4. add people memory foundation
5. add minimal health checks for embeddings

---

## deliverables (MVP)

- [x] goals as data: `memory/goals/` with 3 temporal lenses + auto-update writers
- [x] goal detector with retrieval bias mapping (goal-router SKILL.md + AGENTS.md prompt)
- [ ] auto-digest from raw → `memory/context/daily/YYYY-MM-DD.md` (partial: nightly-synthesis runs but no daily/ output)
- [ ] people memory structure with update path
- [ ] embeddings health check (exists in HEARTBEAT.md, needs live verification)

---

## open questions (clarify before implementation)

- ~~where should goals live: `memory/goals/` vs `custom/goals.md`?~~ → DECIDED: `memory/goals/` with 3 files
- is it acceptable to update `USER.md`, or should goals live separately? → goals live separately
- ~~should auto-digest run via cron, hook, or manual trigger?~~ → DECIDED: nightly-synthesis (jittered heartbeat)
- ~~should goal routing be a skill, a prompt rule, or a hook?~~ → DECIDED: prompt rule (AGENTS.md) + skill descriptor (SKILL.md). no code needed for MVP

---

## constraints

- do not deploy server config changes from local repo
- prefer minimal changes that can be rolled back
- keep prompts aligned with existing voice and security constraints
- do not assume long-term goals exist unless written in files

---

## suggested first pass (you can adjust)

1. propose the goals-as-data format and location
2. implement goal routing MVP (skill or prompt rule)
3. wire retrieval bias configuration
4. implement auto-digest flow
5. outline people memory update mechanism
6. add a basic embedding health check note or script

---

## how to update this plan

- append updates under a dated section
- keep decisions and rationale short
- record what was implemented vs deferred

## updates

### 2026-02-09 (session 2 — implementation)

**target 1: goals as data** — DONE
- `memory/goals/` with 3 temporal files: immediate.md, weekly.md, strategic.md
- cognitive light cone: immediate (< 24h) → weekly (~week) → strategic (> month)
- seeded all 3 with current state

**writers deployed:**
- immediate → memoryFlush prompt (before compaction, identity recovery anchor)
- weekly → nightly-synthesis, every night, `prompts/weekly-lens.md`
- strategic → nightly-synthesis, Sundays only, `prompts/strategic-lens.md`
- all 3 prompts live in `skills/nightly-synthesis/prompts/`
- HEARTBEAT.md and SKILL.md updated

**infra fixes (prerequisite):**
- root cause of embeddings failure: shadow `openclaw.json` with `text-embedding-004` overrode `moltbot.json`
- merged moltbot.json into openclaw.json, deleted moltbot.json (single config now)
- fixed `hooks.entries` and top-level `workspace` (unrecognized keys)
- embeddings model now correct, DB creation pending first search

**decisions:**
- goals/ vs alignment.yaml: orthogonal. alignment = what matters (flat). goals/ = when (temporal). both needed
- immediate writer = memoryFlush (not nightly), because it's the last chance before context loss
- strategic only on Sundays to avoid churn from daily noise

**deferred:**
- ~~target 2: goal routing / retrieval bias~~ — DONE (prompt-level, see below)
- target 3: daily digest (context/daily/) — not started (nightly-synthesis covers some of this)
- target 4: people memory — not started
- target 5: embeddings health check — HEARTBEAT.md already has it, needs verification

**next:**
- verify embeddings DB creates after first search
- verify nightly-synthesis writes weekly.md tonight
- verify memoryFlush writes immediate.md on compaction
- implement goal routing (phase 2 of second-brain.md)

**target 2: goal routing** — DONE (prompt-level MVP)
- rewrote `skills/goal-router/SKILL.md` to match real memory structure (not fantasy dirs)
- added Goal Routing + Goals sections to AGENTS.md
- approach: prompt-based, not code. agent detects goal from message, biases search accordingly
- goal table: technical, recall, plan, reflect, write, general → each maps to real files
- agent reads goals/immediate.md at session start for context recovery
- decision: prompt-level routing is sufficient for now. code-level (hooks) deferred until we see it's needed

**context overflow systemic fix:**
- root cause: group sessions grow unbounded, compaction doesn't fire fast enough
- openclaw loads 7 bootstrap files into every prompt (AGENTS, SOUL, TOOLS, IDENTITY, USER, HEARTBEAT, BOOTSTRAP) capped at 20K chars each
- session history is the real problem — groups with multiple bots/users grow fast
- fix: added `sessions.resetByType.group = { mode: "idle", idleMinutes: 30 }` — group sessions auto-reset after 30 min idle
- dm sessions stay daily reset (default)
- also: `reserveTokensFloor: 50000` gives compaction more runway

**next:**
- deploy AGENTS.md to server (safe-push)
- verify bot reads goals/immediate.md on session start
- target 3: daily digest (context/daily/)
- target 4: people memory

### 2026-02-09

- initial plan drafted
