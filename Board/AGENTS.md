---
name: wenshu-board-agents
description: Wenshu Board SSOT hard rules + project baseline. Load on every wenshu-board turn.
version: 1.0.0
license: MIT
platforms: [macos]
metadata:
  hermes:
    tags: [wenshu, board, ssot, hard-rule]
    default_on: true
    category: policy
    note: "SSOT. English-only. 1-3 lines per rule. No narrative."
related_skills: [wenshu-pocock-workflow, wenshu-parallel-dev, wenshu-apple-api-first]
---

# AGENTS.md — Wenshu Board SSOT

SSOT for every contributor and agent on /Volumes/ANAN/Engineering/wenshu/ (the
client at Board/). The desktop app is at the repository root; the phone and
tablet client is at Mobile/. This file governs the card board.

## §0 Load order (read on every wenshu-board turn)

> Order matters. Skip = silent drift.

1. AGENTS.md (this file) — 10 sections of project SSOT (reached via the
   Board/.hermes.md pointer; see 1.9).
2. ~/.hermes/shared/wenshu-skills/wenshu-pocock-workflow/SKILL.md — workflow entry.
3. ~/.hermes/shared/wenshu-skills/wenshu-pocock-workflow/references/wenshu-swift-standards.md — Swift standards.
4. Board/docs/board-plan.md — what the client is for, and the open decisions.
5. OOB.md if any rule references (see OOB.md #YYYY-MM-DD).

## §1 Hard rules (project-wide, non-negotiable)

| #   | Rule | Enforcement |
| --- | ---- | ----------- |
| 1.1 | English-only in code, comments, commits, prompts, all .md, except OOB.md. No CJK characters. | CI lint-commits job (no CJK in the subject); the xianxia family by commit_filter.py + SwiftLint. Comment-level CJK is manual. |
| 1.2 | Sole address for the user = "老板". No other forms. | Manual. commit_filter.py permits the project literals (老板 / 文枢 / 拍 / 拍板 / ※). |
| 1.3 | Forbidden hedges (replace with yes/no/yes-yes): 可 / 应当 / 或许 / 可能 / 应该 / 建议 / 考虑 / 试图 / 尽量 / 大概 / 也许 / 或 / 任意 / 大概率 / 通常 / 一般来说. | Manual (= no machine gate). |
| 1.4 | Forbidden xianxia vocabulary (replace with 修 / 改 / fix / 替换 / 调整): 修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹 / 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障. | commit_filter.py (pre-commit + commit-msg hooks in .git/hooks/) + .swiftlint.yml xianxia_forbidden_vocab (severity error). |
| 1.5 | Comment policy: engineering intent only. Forbidden: boss directive text, ticket IDs, Q-numbers, version narratives, phase numbering, refactor history, ticket lineage. | Manual. |
| 1.6 | OOB references in code: only (see OOB.md #YYYY-MM-DD). Never directive text inline. | Manual. |
| 1.7 | NFI registration: every extracted or added file MUST be registered in docs/agents/nfi.md with parent ref + LOC + content tag. Discoverable < 5s by name. Register a new row there, not here. | Manual. |
| 1.8 | High information density. One line per argument. No narrative paragraphs. | Manual; shape = to-spec. |
| 1.9 | Load chain: Board/.hermes.md is the file Hermes injects when the session opens in the client's directory (it wins over Board/AGENTS.md) and points here + at the skill chain. A skill body loads on demand via skill_view; only its description is injected. | Board/.hermes.md. |
| 1.10 | One ticket = one commit + one atomic verification + one 4-section spec + one dual-axis dispatch + one P0 fix + one verify round + merge gate. | Tools/wenshu-devtool/ticket_tier.py; Scripts/merge-preflight.sh. |
| 1.11 | The NFI registry = docs/agents/nfi.md: one row per extracted or added file, append-only. `merge=nfi-registry` in .gitattributes merges two cards' rows at the key level. | docs/agents/nfi.md. |
| 1.12 | Parallel worktree isolation: every code-changing ticket runs in its own git worktree, never the shared checkout. `delegate_task` is read-only fan-out: its children inherit the parent cwd, so a relative write lands in the shared checkout. | wenshu-parallel-dev |
| 1.13 | Difficulty tier: every card carries a tier (`[T1]` / `[T2]` / `[T3]`), DERIVED by ticket_tier.py from the work its body describes, never hand-set. The tier sets the runtime cap, retry budget, gate width and body budget = cost, not quality: it never skips the dual-axis review, never marks a test skipped. | ticket_tier.py; docs/agents/ticket-tiers.md. |
| 1.14 | Independent review: a card that writes CODE carries a `## REVIEW HANDOFF` naming a reviewer profile that is NOT its implementer. The obligation is DERIVED from the work the body describes, never the tier; a prose-only card owes no verdict. | Tools/wenshu-devtool/review_gate.py; Scripts/merge-preflight.sh. |
| 1.15 | Evidence before code: a card that reads names its read list, stop condition, forbidden lookups and deliverable in an `## EVIDENCE BUDGET` section, and its write order in `## WHAT TO BUILD`. `ready` means executable. | Tools/wenshu-devtool/effort_budget_gate.py (the gate is 7.11). |

## §2 Stack baseline

> Lock these. New framework requires a boss ruling.

| #   | Fact | Reference |
| --- | ---- | --------- |
| 2.1 | Stack: Swift / SwiftUI / Observation / SwiftData (read side) / Swift Concurrency. | Apple stack exclusive. |
| 2.2 | NO CoreData. NO SQLite (SwiftData only). NO external AI platform SDK. NO npm. NO Python in the app target. NO Rust. NO Tauri. NO Vue. | Board/Package.swift (tools-version 6.4). |
| 2.3 | macOS-only, floor macOS 27, the same floor as the desktop app and as `WenshuData`. The board is a Mac surface: it opens the same `.ws`, so it needs the same platform, and it does not widen the shared package's manifest. | Board/Package.swift; ADR-0034. |
| 2.4 | Swift 6 strict concurrency. @MainActor for UI. actor for background. Sendable for cross-isolation. | wenshu-swift-standards.md §4. |
| 2.5 | Two targets: `WenshuBoardKit` (the card model) and `WenshuBoardApp` (the executable). No second app target. | Board/Package.swift. |
| 2.6 | The desktop app is an executable target and is NOT a dependency of this package. Its views, its icon factory and its design tokens are not consumable, so this client cannot reuse them. | ADR-0034. |
| 2.7 | Tests: Swift Testing (`import Testing`). Legacy XCTest files stay; add none. | Tests/. |
| 2.8 | Version: three digits, middle = phase, third = hotfix. | Boss ruling. |
| 2.9 | Project root: /Volumes/ANAN/Engineering/wenshu/ (the client at Board/). | Canonical. |
| 2.10 | The shared model layer is consumed as a local path package (`../Sources/WenshuData`), so both sides resolve the same bytes by construction. A dependency path may leave the package root; a TARGET path may not. | Board/Package.swift; ADR-0034. |

## §3 The board is a reader of the library

> One library, one writer. The desktop app owns it.

| #   | Fact | Reference |
| --- | ---- | --------- |
| 3.1 | The desktop app is the only writer of a `.ws`. This client reads one and must never write a `.ws` the desktop app has open. | Board/docs/board-plan.md §8. |
| 3.2 | A chapter's body lives in the FILE tier (`shelves/<shelf>/books/<book>/chapters/<uuid>.md`). The SwiftData chapter row is in the schema and holds zero rows on a live library, because the store that would populate it is never instantiated in production. | Board/docs/board-plan.md §7. |
| 3.3 | The chapter index beside the bodies (`chapters.json`) has a writer that emits one object and readers that expect an array, and the decode failure is swallowed into an empty list. The client does not depend on that index; it reads the bodies. | Board/docs/board-plan.md §7. |
| 3.4 | The chapter's domain model (`Document`) lives in the desktop app's target, so the client cannot see it. The client reads the files and carries its own reader. | ChapterFileReader. |
| 3.5 | The chapter's order is the file name's. The desktop app sorts documents by pinyin, creation date or modification date, and none of those is a chapter number. | ChapterFileReader. |

## §4 The card model

> One envelope, many kinds. Ported from the measured reference.

| #   | Fact | Reference |
| --- | ---- | --------- |
| 4.1 | A board, a column and a card are the SAME record (`BoardElement`); only the kind differs, so a container holds cards and boards alike. | Board/docs/milanote-card-model.md §2. |
| 4.2 | One `location` carries both placement regimes: a free canvas (`x`/`y` + a z-order score) and an ordered list (an ordinal + an order key). | Board/docs/milanote-card-model.md §4. |
| 4.3 | The order key's step is 65536 and a card placed above the head takes a negative rung, so an insert does not renumber the list. A batch insert splits the gap by (n + 1), and an insert with no room between its neighbours asks for a rebalance instead of writing a colliding key. | BoardOrderKey; Board/docs/milanote-card-model.md (the order key in the reference's own source). |
| 4.4 | The payload is an open path map, not a union of every field, so a kind decides the meaning of its values. | BoardContent; Board/docs/milanote-card-model.md §6. |
| 4.5 | A card's text is Markdown. The reference stores a ProseMirror document and the conversion belongs at the boundary; the reference's per-block identity key is NOT copied, because it exists to reconcile a ProseMirror re-parse. | Board/docs/board-plan.md §5. |
| 4.6 | The canvas regime IS in scope. Apple ships no infinite canvas on macOS (`PKCanvasView` is exported by PencilKit, but Apple ships no header for it on macOS and the macOS Swift interface does not expose it, and macOS 27 adds no infinite canvas of its own), so the client builds it from the public pieces: `SwiftUICore.Canvas`, `MagnifyGesture`, `DragGesture`, `ScrollGeometry`, `zIndex`, `drawingGroup`. | Board/docs/freeform-card-model.md §3; Board/docs/board-plan.md §4. |
| 4.7 | No freeform file format. Apple's board package is not documented, and the macOS app does not write one at all (= it is an import format there: the File menu offers PDF, share and print, and nothing else), so reading or writing one is not a commitment. The Apple-canonical route to an Apple board is an App Intent. | Board/docs/freeform-card-model.md §2.5 and §5.4. |
| 4.8 | The viewport is the canvas's arithmetic and it is a pure function: a zoom keeps the world point under the anchor under the anchor, a scale clamps to [0.2, 4.0], and an item off screen is neither drawn nor hit tested. The arithmetic lives in the Kit, the gestures in the view. | BoardViewport. |
| 4.9 | The canvas is a LAYOUT TREE, not a flat list: every item is a layout with a transform chain to the root, a clip rect and a culling bound. A live manipulation keeps a dynamic geometry beside the committed one, and only the committed one is written, so a drag is not a write. The scale is a view concern: the model is in unscaled units. | Board/docs/freeform-card-model.md §4. |
| 4.10 | The canvas is a VIEW over the same data, not a migration: `location.section` decides which regime reads which field of the position, so a card moves between the column and the free canvas by changing its section and nothing else. | Board/docs/milanote-card-model.md §4 (the section-to-field table); Board/docs/freeform-card-model.md §4.6 (the data and view seam); Board/docs/board-plan.md §4. |

## §5 Third-party library policy

> Default = Apple stack exclusive. Exceptions require a 4-gate pass.

| #   | Fact | Reference |
| --- | ---- | --------- |
| 5.1 | Default: Apple stack only. Board/Sources/ imports only Apple frameworks and the local packages. | Board/Package.swift; manual review. |
| 5.2 | Third-party exceptions need ALL 4: (a) >=100 stars, (b) commit <=12 months, (c) MIT/Apache/BSD/PD, (d) macOS-supported. | Boss ruling 8/27 (OOB.md). |
| 5.3 | Icons = SF Symbols 6 (built-in, zero SPM). NEVER lucide-swift. The desktop app's icon factory is in its app target and is NOT consumable here, so this client needs its own one-icon-factory answer. **Open.** | Board/docs/board-plan.md §4. |
| 5.4 | Approved deps (= the repository's upstreams.json): the CLIENT has none of its own; the desktop's four are not the client's. | upstreams.json. |
| 5.5 | New dep: 1-page rationale + the 4 gates in 5.2 + a boss ruling. Then upstreams-scan.py regenerates upstreams.json. | OOB.md. |

## §6 Project structure (canonical target)

> One feature = one self-contained folder. Apple Backyard Birds template.

| #   | Fact | Reference |
| --- | ---- | --------- |
| 6.1 | Board/Sources/ = 2 SwiftPM targets: WenshuBoardKit/ (the card model, no views) and WenshuBoardApp/ (the executable: App/ + Features/<Name>/ + Shared/). Board/Tests/ = the test target. | Board/Package.swift. |
| 6.2 | A feature folder uses up to 4 slots: Model/ + Service/ + Store/ + View/. A feature carries only the slots it needs. | Board/Sources/WenshuBoardApp/Features. |
| 6.3 | Cross-feature code lives in Board/Sources/WenshuBoardApp/Shared/; the card model both sides agree on lives in Board/Sources/WenshuBoardKit/. | Shared/; WenshuBoardKit. |
| 6.4 | File naming suffix by role: <Xxx>View / <Xxx>Ops / <Xxx>Service / <Xxx>State .swift. One concern per file. | wenshu-swift-standards.md §1.2. |
| 6.5 | File size cap: 600 LOC per .swift file. Exceed = split, and register the split in the NFI (1.7). | wenshu-swift-standards.md §1.2. |
| 6.6 | One import block per file. Alphabetical. No unused imports. | wenshu-swift-standards.md §1.1. |
| 6.7 | Single-purpose rule. Any dir with exactly 1 file and 0 dependents = deletion candidate. | Boss OOB 2026-10-16. |
| 6.8 | Top-level purpose map. Board/docs/ = the plan + the two reference teardowns + the client's ADRs. Board/Tests/ = the Swift test target. | Board/README.md. |
| 6.9 | The reference teardowns live in Board/docs/, not in the repository's docs/agents/: they are the client's inputs, not the repository's governance record. | Board/docs/board-plan.md (the measured facts section). |

## §7 Verification & quality gates

> Two classes. §7.1-§7.10 gate a landed diff. §7.11-§7.12 fire before the code exists.

### Merge-blocking gates (the diff must pass all ten)

| #   | Gate | Reference |
| --- | ---- | --------- |
| 7.1 | `swift build` exits 0 in Board/. | CI. |
| 7.2 | `swift test` exits 0 in Board/. No skipped test without // TODO + tracker id. | CI. |
| 7.3 | Design sweep: zero naked `Image(systemName:)`, zero inline `.cornerRadius(N)`, zero `.font(.system(size:))`, zero magic spacing in the changed view files. | Tools/wenshu-devtool/design-sweep.sh (the desktop copy is the semantic SSOT). |
| 7.4 | Dual-axis audit: Standards axis (code-review + codebase-design) + Spec axis (the card's 4-section spec). Both read-only, parallel. | docs/agents/parallel-development.md; wenshu-parallel-dev. |
| 7.5 | CJK comment audit: zero new CJK in the modified file. | CI lint-commits job. |
| 7.6 | No dead code. | Tools/wenshu-devtool/verify-dead.py. |
| 7.7 | UI-touching ticket: the boss looks at the running build in person. A screenshot is evidence only when asked. The worker's GUI drive = the `computer_use` tool in background delivery: never synthetic mouse/keyboard events, never the user's cursor or foreground. | OOB.md. |
| 7.8 | Commit hygiene: 1 commit per ticket, conventional prefix, English subject, body explains WHY. | CI lint-commits job; commit_filter.py commit-msg hook. |
| 7.9 | Independent review verdict: the REVIEWER ends with `kanban_complete(metadata={"review_outcome": "approved"})` = the field the gate reads, so a verdict in the summary alone is NO verdict, and it is never backfilled by hand. | Tools/wenshu-devtool/review_gate.py. |
| 7.10 | Named narrow gate: a card's body names the filtered suite that owns each file it writes, as a `swift test --filter <Suite>` command. A T1/T2 card never asks for the whole suite. | Tools/wenshu-devtool/gate_width_gate.py. |

### Intake and dispatch gates (they fire before the code exists)

| #   | Gate | Reference |
| --- | ---- | --------- |
| 7.11 | Evidence budget: this gate checks rule 1.15's four lines AND the order shape (line-numbered seams, one writer per file) before a worker starts. A card that reads without a budget is a defect. | Tools/wenshu-devtool/effort_budget_gate.py. |
| 7.12 | Fan-out budget: a card that opens sub-agents names disjoint scopes, one writer per file, and the parent's total call ceiling. | Tools/wenshu-devtool/session_effort_audit.py. |

## §8 Workflow (universal PO methodology)

> One ticket = §8.1 -> §8.10 in order. Skip = fail.

| #   | Step | Skill |
| --- | ---- | ----- |
| 8.1 | Evidence budget: name the read list, stop condition, forbidden lookups and deliverable. The research happens BEFORE the card, so the card is an order. | rule 1.15; Tools/wenshu-devtool/effort_budget_gate.py. |
| 8.2 | Design card: the Apple canonical API, the target shape, the stop condition. One page. | wenshu-apple-api-first. |
| 8.3 | 4-section business-language spec (business / current state / Apple canonical / after-fix). The Apple-canonical section IS the design card from 8.2, never a restatement. | wenshu-pocock-workflow + universal-pocock-workflow. |
| 8.4 | Code + smoke test + reproduce, in a worktree (rule 1.12). | diagnosing-bugs; wenshu-parallel-dev. |
| 8.5 | Real violation inventory (read-only): the grep inventory of the affected area, by rule. | §7.3. |
| 8.6 | Fan-out budget: disjoint scopes, one writer per file, the parent's call ceiling, one shared evidence pack. | rule 7.12; Tools/wenshu-devtool/session_effort_audit.py. |
| 8.7 | Dual-axis dispatch (Standards + Spec, 2 parallel read-only sub-agents). | code-review; codebase-design. |
| 8.8 | Fix P0. | universal-pocock-workflow step 5. |
| 8.9 | Verify round over the files the fix commit touched. | universal-pocock-workflow step 6. |
| 8.10 | Merge gate (boss verdict for UI; swift build for non-UI). The card's DISPATCHER verifies, merges and pushes it: the worker finishing and the reviewer approving are automatic, the branch landing is not. A card is LANDED when its branch is on `main` AND `main` is on the remote. | Scripts/merge-preflight.sh. |

## §9 Reference index (NOT duplicated here)

> Link, do not restate. SSOT = this-file-row. A bare tool name = that tool under Tools/wenshu-devtool/; a bare skill name = its skill dir; other paths are repo-relative.

| Topic | Link |
| ----- | ---- |
| The client's plan, the phases, the open decisions | Board/docs/board-plan.md |
| Milanote: the data model, measured live | Board/docs/milanote-card-model.md |
| Apple Freeform: the board app, the App Intents, the SDK quotes | Board/docs/freeform-card-model.md |
| The client's package boundary | Board/docs/adr/0034-the-board-client-is-its-own-package.md |
| The client's writer rule | Board/docs/adr/0035-one-library-one-writer.md |
| Swift standards + AI self-check | wenshu-pocock-workflow/references/wenshu-swift-standards.md |
| PO methodology | universal-pocock-workflow/SKILL.md |
| Apple HIG canonical | wenshu-apple-api-first/SKILL.md |
| Parallel dev convention (worktree board cards) | wenshu-parallel-dev/SKILL.md |
| Nervous file index (NFI) | docs/agents/nfi.md |
| Ticket difficulty tiers | docs/agents/ticket-tiers.md |
| OOB index (boss directives, dev-time only) | OOB.md |
| The desktop app's SSOT | AGENTS.md |
| The phone client's SSOT | Mobile/AGENTS.md |

## §10 Change protocol for THIS file

> AGENTS.md is SSOT. Touch with care.

| #   | Rule |
| --- | ---- |
| 10.1 | Edit trigger = boss OOB only. Never edit during a normal ticket. |
| 10.2 | New rule = add numbered row (§1.X / §2.X / etc.). Never insert between rows. |
| 10.3 | Remove rule = delete from this file. No history. Outdated = gone. |
| 10.4 | Pre-flight before committing this file: `python3 Tools/wenshu-devtool/agents_gate.py --file AGENTS.md` exits 0. It checks the frontmatter parses, the file fits the loader's context-file cap, every named path and skill exists, the rule ids are contiguous, and no CJK hides outside 1.2-1.4. |

> First line fact: Wenshu Board is a macOS card-board client that reads a Wenshu library and borrows its card model from two measured references.
> Last line fact: This file is SSOT for wenshu-board; all detail lives in §9 reference index.
