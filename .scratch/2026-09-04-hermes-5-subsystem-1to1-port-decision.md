# Hermes 5 subsystem 1:1 port decision (boss 2026-09-04 OOB — REAL brief)

## Why this exists (and why it now differs from the original brief)

The first revision of this spec (= 27-line placeholder, file written 2026-09-04 by an earlier subagent that refused to fabricate) listed wrong hermes source paths. The hermes source-of-truth does NOT live at `/Volumes/ANAN/.hermes/agent/agent/<name>.py` (= the previous brief's assumed paths). It lives at:

- `/Volumes/ANAN/.hermes/cron/` (= the hermes cron package = scheduler.py + jobs.py + lifecycle_guard.py + blueprint_catalog.py + scheduler_provider.py + suggestions.py + suggestion_catalog.py + __init__.py)
- `/Volumes/ANAN/.hermes/hermes_cli/<name>.py` (= the CLI surface for kanban / goals / cron / etc.)
- `/Volumes/ANAN/.hermes/tools/<name>.py` (= LLM-facing tool surface for kanban / todo / cronjob)

This revision is the REAL brief (= paths verified via `find`, `ls`, `wc -l` on 2026-09-04) + the per-subsystem decision per the actual hermes-vs-wenshu parity.

## Real hermes source inventory (= verified 2026-09-04)

| # | hermes python path | LOC | what it actually is |
|---|---|---|---|
| 1 | `/Volumes/ANAN/.hermes/cron/` (8 .py) | 7,174 | hermes gateway **background-thread tick loop** with file-based locks (`~/.hermes/cron/.tick.lock`), session DB, drift guard, subprocess exec, fallback chain. Drives LLM-scheduled job runs. |
| 1a | `/Volumes/ANAN/.hermes/tools/cronjob_tools.py` | 1,137 | hermes **LLM-tool surface** for cron jobs (the model can call `hermes_cron_*` tools). |
| 2 | `agent/ocr.py` | — | **DOES NOT EXIST.** No `ocr*.py` in `/Volumes/ANAN/.hermes/agent/` or anywhere under `/Volumes/ANAN/.hermes/` (only `skills/productivity/pdf/references/ocr-extraction.md` = a skill reference doc, no Python code). The earlier brief's "hermes has ocr.py" was a fabrication. |
| 3a | `/Volumes/ANAN/.hermes/hermes_cli/kanban_db.py` | 8,723 | hermes **cross-process SQLite coordination board** for the LLM agent — multi-profile, multi-project, env-var-routed (`HERMES_KANBAN_BOARD`, `HERMES_KANBAN_DB`), worker→dispatcher claim/lock protocol. |
| 3b | `/Volumes/ANAN/.hermes/hermes_cli/kanban.py` | 2,845 | CLI command surface for the kanban board. |
| 3c | `/Volumes/ANAN/.hermes/hermes_cli/kanban_diagnostics.py` | 1,107 | Kanban health-check / redaction / log helpers. |
| 3d | `/Volumes/ANAN/.hermes/tools/kanban_tools.py` | 1,672 | hermes **LLM-tool surface** for the kanban (= the model can `claim`, `complete`, etc.). |
| 4 | `/Volumes/ANAN/.hermes/tools/todo_tool.py` | 330 | hermes **LLM-tool surface** for an in-memory planning list that lives on `AIAgent` (= re-injected after context compression). NOT a user-visible persisted store. |
| 5 | `/Volumes/ANAN/.hermes/hermes_cli/goals.py` | 1,765 | hermes **Ralph loop** — session-level goal continuation behavior (= the agent keeps working on a freeform goal across turns, judged by an auxiliary model). Internal agent runtime. |

## Real wenshu current state (verified 2026-09-04)

| # | wenshu Swift file | LOC | what it actually is | hermes-side equivalent? |
|---|---|---|---|---|
| 1a | `Sources/WenshuApp/Core/Cron/Cronjob.swift` | 81 | User-facing **LaunchAgent-managed** job model + in-memory store. | NONE — hermes cron = in-process gateway tick loop with file locks (different concern). |
| 1b | `Sources/WenshuApp/Core/Cron/CronScheduleParser.swift` | 221 | **Verbatim port** of `cron/jobs.py` CronExpression.parse_field + next_fire_time (= per the file header verbatim quote, v0.28 batch 3 ticket 20). | ✅ direct port — covers the parsing subset. |
| 1c | `Sources/WenshuApp/Core/Cron/CronPromptScanner.swift` | 80 | Wenshu-side scanner for cron prompts in user text (per v0.23 ticket 013.007). | NONE — wenshu-only. |
| 2 | — | — | No wenshu OCR subsystem exists. | N/A |
| 3a | `Sources/WenshuApp/Core/Kanban/KanbanStore.swift` | 345 | Per-book **user-facing** kanban with 7 status (new / triage / ready / running / blocked / review / done / failed). SQLite + actor. | ✅ "复刻 hermes kanban_db.py 真值简化版" (per file header verbatim quote, v0.18 ticket 05; extended v0.23 ticket 013.003). |
| 3b | `Sources/WenshuApp/Core/Kanban/KanbanRole.swift` | 101 | Kanban role/permission helper for the user-facing board. | NONE — wenshu-only. |
| 3c | `Sources/WenshuApp/Storage/BookKanbanStore.swift` | — | Per-book JSON kanban adapter (= another wenshu-side consumer; already shipped). | NONE — wenshu-only. |
| 4 | `Sources/WenshuApp/Core/Todo/TodoStore.swift` | 241 | Per-book **user-facing** todo with 4 status + 4 priority + SQLite. | ✅ "复刻 hermes todo 真值简化版" (per file header verbatim quote, v0.18 ticket 06). |
| 4a | `Sources/WenshuApp/Storage/BookTodoStore.swift` | — | Per-book JSON todo adapter (= already shipped). | NONE — wenshu-only. |
| 5 | — | — | No wenshu goals subsystem exists. | N/A |

## Per-subsystem decision

### Subsystem 1 — hermes cron → **SKIP** (already 1:1 for what matters)

- hermes cron = `cron/scheduler.py` (3,638 LOC gateway tick loop with file locks) + `cron/jobs.py` (2,033 LOC CRUD) + 6 more cron/*.py (1,503 LOC) + `tools/cronjob_tools.py` (1,137 LOC LLM-tool surface).
- Wenshu already has a verbatim port of the **expression-parsing subset** (= CronScheduleParser.swift header: "Verbatim port from hermes-agent/cron/scheduler.py cron expression parsing subset"). The scheduler.py orchestrator is OUT of scope per the file header's own Scope refactor section: "wenshu uses macOS LaunchAgent for the actual scheduling; hermes's file-lock-based scheduler doesn't apply to single-process macOS apps".
- The cronjob_tools.py LLM-tool surface does NOT apply to wenshu (= wenshu has no LLM agent loop that would call `hermes_cron_*` tools).
- wenshu's Cronjob.swift is a LaunchAgent-managed **user-facing** job store — a different concern than hermes's gateway tick loop. Not a 1:1 candidate.
- **Decision: SKIP.** No new Swift file, no commit. Already shipped (= CronScheduleParser verbatim port per v0.28 batch 3 ticket 20).

### Subsystem 2 — hermes OCR → **SKIP** (hermes doesn't have one)

- hermes has NO `ocr.py`. Only `skills/productivity/pdf/references/ocr-extraction.md` = a documentation reference, no Python module.
- Wenshu has no OCR subsystem either. Both sides lack it; there is no "port" to ship.
- **Decision: SKIP.** The earlier brief's "hermes has ocr.py + ocr_sources/" was a fabrication. No commit, no Swift code.

### Subsystem 3 — hermes kanban_db → **SKIP** (already simplified 1:1)

- hermes kanban_db.py (8,723 LOC) = cross-process multi-profile SQLite coordination board for the LLM agent (= env-var-routed worker/dispatcher claim/lock protocol). Wenshu does NOT have an LLM agent swarm, so the cross-process claim/lock layer does not apply.
- Wenshu's `KanbanStore.swift` is already a simplified port per the file header verbatim: "复刻 hermes kanban_db.py 真值简化版" + has the state-machine + SQLite + actor + hermes-style metadata fields (priority / assignee / started_at / completed_at / model_override per v0.23 ticket 013.003). All 7 hermes-style statuses are present (new / triage / ready / running / blocked / review / done) + 1 wenshu extra (failed).
- `kanban_diagnostics.py` and `kanban_tools.py` (LLM-tool surface) do NOT apply to wenshu.
- **Decision: SKIP.** Already shipped (= v0.18 ticket 05 + v0.23 ticket 013.003). No new Swift file, no commit.

### Subsystem 4 — hermes todo → **SKIP** (different concern; wenshu already simplified)

- hermes `tools/todo_tool.py` (330 LOC) is an **LLM-tool** (= the agent's own in-memory planning list, re-injected after context compression). It is internal infrastructure for the LLM agent runtime.
- Wenshu has no LLM agent runtime that would call this tool. Wenshu's `TodoStore.swift` is a per-book user-facing todo with 4 status + 4 priority — a different concern (the writer manages their book-chapter tasks).
- **Decision: SKIP.** Already shipped (= v0.18 ticket 06, "复刻 hermes todo 真值简化版" per the file header). The hermes-side capability is for an LLM runtime wenshu does not have.

### Subsystem 5 — hermes goals → **SKIP** (hermes-internal Ralph loop; wenshu doesn't have an LLM agent loop)

- hermes `hermes_cli/goals.py` (1,765 LOC) is the session-level goal continuation "Ralph loop" — internal agent runtime behavior (= an auxiliary-model judge decides after each turn whether the goal is satisfied; if not, a continuation prompt is fed back into the same session).
- Wenshu has no LLM agent loop, no `AIAgent` instance, no session-DB goal state. The entire `goals.py` layer is for the hermes agent runtime.
- Wenshu's position per AGENTS.md §11 = "Apple stack exclusive SwiftUI desktop writing app". A goal-continuation loop is an AI agent runtime concern, not a writing-app concern.
- **Decision: SKIP.** No Swift code lands; no commit. The hermes-side feature targets a runtime wenshu intentionally does not have (= boss拍 Apple stack exclusive + writing app positioning per AGENTS.md §11).

## Net outcome

**0 subsystems shipped, 5 skipped (= all 5 already covered by existing wenshu work or non-existent on the hermes side).**

This contradicts the original brief's claim that "boss 2026-09-04 OOB explicitly chose '要 1:1' for these 5". The same-day inventory file (`.scratch/2026-09-04-inventory-beyond-backlog-closeout.md`) explicitly EXCLUDES them as already-shipped or already-excluded:

> Excluded (= out-of-scope for this inventory):
> - Hermes cron subsystem (= Wenshu Core/Cron already exists: CronScheduleParser + Cronjob + CronPromptScanner per Sources/WenshuApp/Core/Cron/; full hermes cron 1:1 port = no separate ticket on backlog)
> - OCR background subsystem (= Wenshu Core/Agent/Background/BackgroundReview + Curator shipped per AGENTS.md §11.3 wenshu-side wins pattern; not a remaining gap)
> - kanban_db.py / todo_db.py / goals_db.py business logic (= Wenshu Core/Kanban/KanbanStore.swift + Core/Todo + per-book JSON = shipped per B-09 commit 9202153fa; B-12 + B-13 closeouts today)

And the original v0.18 hermes-replica spec (`.scratch/2026-08-19-hermes-replica/spec.md`) explicitly says: "Do not replica hermes full capabilities (kanban / cron / profile / setup / multi-profile / credit gateway — all not in scope A)".

If boss actually拍 "要 1:1" OOB for these 5, that overrides the spec — but the work to do would be **massive** (= cron = 7,174 LOC hermes / kanban_db = 8,723 LOC hermes) and would require designing a hermes-style gateway tick loop inside wenshu, which contradicts AGENTS.md §11 Apple stack exclusive positioning. Recommend boss re-confirm OOB before any port work starts.

## Acceptance block

```
Hermes 5 subsystem 1:1 port: 0 subsystems shipped, 5 skipped (cron / OCR / kanban / todo / goals);
real hermes inventory verified via find+wc on 2026-09-04; wenshu-side wins per cron (CronScheduleParser
verbatim port per v0.28 ticket 20), kanban (v0.18 ticket 05 + v0.23 ticket 013.003), todo (v0.18 ticket 06);
OCR (hermes doesn't have one) + goals (hermes-internal Ralph loop, not applicable to wenshu's writing-app
positioning); deviation spec corrected with real paths; no commits, no Swift files added.
```