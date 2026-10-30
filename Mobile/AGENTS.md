---
name: wenshu-mobile-agents
description: Wenshu Mobile SSOT hard rules + project baseline. Load on every wenshu-mobile turn.
version: 1.0.0
license: MIT
platforms: [ios]
metadata:
  hermes:
    tags: [wenshu, mobile, ssot, hard-rule]
    default_on: true
    category: policy
    note: "SSOT. English-only. 1-3 lines per rule. No narrative."
related_skills: [wenshu-pocock-workflow, wenshu-parallel-dev, wenshu-apple-api-first]
---

# AGENTS.md — Wenshu Mobile SSOT

SSOT for every contributor and agent on /Volumes/ANAN/Engineering/wenshu/ (the client at Mobile/).
The desktop repo (wenshu) keeps the macOS app; this repo keeps the phone and
tablet client, its shared kit, and the mobile half of the product line, with the
client under Mobile/.

## §0 Load order (read on every wenshu-mobile turn)

> Order matters. Skip = silent drift.

1. AGENTS.md (this file) — 10 sections of project SSOT (reached via the .hermes.md pointer; see 1.9).
2. ~/.hermes/shared/wenshu-skills/wenshu-pocock-workflow/SKILL.md — workflow entry.
3. ~/.hermes/shared/wenshu-skills/wenshu-pocock-workflow/references/wenshu-swift-standards.md — Swift standards.
4. Mobile/docs/product-line-plan.md — the product line and architecture plan (read before any protocol or sync work).
5. OOB.md if any rule references (see OOB.md #YYYY-MM-DD).

## §1 Hard rules (project-wide, non-negotiable)

> The rules with a machine gate block the commit. A rule whose cell says Manual has no gate.

| #   | Rule | Enforcement |
| --- | ---- | ----------- |
| 1.1 | English-only in code, comments, commits, prompts, all .md, except OOB.md and Mobile/IDEA.md (= the boss's own words, kept verbatim; dev-time only). No CJK characters. | CI lint-commits job (no CJK in the subject); the xianxia family by commit_filter.py + SwiftLint. Comment-level CJK is manual. |
| 1.2 | Sole address for the user = "老板". No other forms. | Manual. commit_filter.py permits the project literals (老板 / 文枢 / 拍 / 拍板 / ※). |
| 1.3 | Forbidden hedges (replace with yes/no/yes-yes): 可 / 应当 / 或许 / 可能 / 应该 / 建议 / 考虑 / 试图 / 尽量 / 大概 / 也许 / 或 / 任意 / 大概率 / 通常 / 一般来说. | Manual (= no machine gate). |
| 1.4 | Forbidden xianxia vocabulary (replace with 修 / 改 / fix / 替换 / 调整): 修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹 / 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障. | commit_filter.py (pre-commit + commit-msg hooks in .git/hooks/) + .swiftlint.yml xianxia_forbidden_vocab (severity error) + CI Pollution check. |
| 1.5 | Comment policy: engineering intent only. Forbidden: boss directive text, ticket ids, version narratives, phase numbering, refactor history, ticket lineage. | Manual. |
| 1.6 | OOB references in code: only (see OOB.md #YYYY-MM-DD). Never directive text inline. | Manual. |
| 1.7 | NFI registration: every extracted or added file MUST be registered in docs/agents/nfi.md with parent ref + LOC + content tag. Discoverable < 5s by name. Register a new row there, not here. | Manual. |
| 1.8 | High information density. One line per argument. No narrative paragraphs. | Manual; shape = to-spec. |
| 1.9 | Load chain: Mobile/.hermes.md is the file Hermes injects when the session opens in the client's directory (it wins over Mobile/AGENTS.md) and points here + at the skill chain. A skill body loads on demand via skill_view; only its description is injected. | .hermes.md. `skills.auto_load` in config.yaml injects a body; a frontmatter `default_on` does not. |
| 1.10 | One ticket = one commit + one atomic verification + one 4-section spec + one dual-axis dispatch + one P0 fix + one verify round + merge gate. | Tools/wenshu-devtool/ticket_tier.py; Scripts/merge-preflight.sh. |
| 1.11 | The NFI registry = docs/agents/nfi.md: one row per extracted or added file, append-only. `merge=nfi-registry` in .gitattributes merges two cards' rows at the key level. | docs/agents/nfi.md. |
| 1.12 | Parallel worktree isolation: every code-changing ticket runs in its own git worktree, never the shared checkout (= a kanban card, `--workspace worktree --project project`, board `wenshu-par`). `delegate_task` is read-only fan-out: its children inherit the parent cwd, so a relative write lands in the shared checkout. | wenshu-parallel-dev |
| 1.13 | Difficulty tier: every card carries a tier (`[T1]` / `[T2]` / `[T3]`), DERIVED by ticket_tier.py from the work its body describes, never hand-set. The tier sets the runtime cap, retry budget, gate width and body budget = cost, not quality: it never skips the dual-axis review, never marks a test skipped. A card in the REVIEW lane answers to that lane's floor, not to its tier's cap. | ticket_tier.py; docs/agents/ticket-tiers.md. |
| 1.14 | Independent review: a card that writes CODE carries a `## REVIEW HANDOFF` naming a reviewer profile that is NOT its implementer, and ends with `kanban_request_review(reviewer=...)`. The obligation is DERIVED from the work the body describes, never the tier; a prose-only card owes no verdict. | Tools/wenshu-devtool/review_gate.py; Scripts/merge-preflight.sh. |
| 1.15 | Evidence before code: a card that reads names its read list, stop condition, forbidden lookups and deliverable in an `## EVIDENCE BUDGET` section, and its write order in `## WHAT TO BUILD`. `ready` means executable. Reading is a cost like a build, and it burns first. | Tools/wenshu-devtool/effort_budget_gate.py (the gate is 7.11). |

## §2 Stack baseline

> Lock these. New framework requires a boss ruling.

| #   | Fact | Reference |
| --- | ---- | --------- |
| 2.1 | Stack: Swift / SwiftUI / Observation (@Observable) / SwiftData (device-local only) / Swift Concurrency. | Apple stack exclusive. |
| 2.2 | NO CoreData. NO SQLite (SwiftData only). NO external AI platform SDK. NO npm. NO Python in the app target. NO Rust. NO Tauri. NO Vue. NO AppKit in the client. | Mobile/Package.swift (tools-version 6.4); Mobile/Sources/ imports = Apple frameworks only. |
| 2.3 | iOS and iPadOS only, one codebase. The iPhone 18 family is the primary target; a foldable is the same adaptive code, adapted to fit, not a second target. | ADR-0032. |
| 2.4 | Swift 6 strict concurrency. @MainActor for UI. actor for background. Sendable for cross-isolation. | wenshu-swift-standards.md §4. |
| 2.5 | One library, one app: WenshuMobileKit (the link contract both sides must agree on) and WenshuMobileApp (the executable). No second app target. | Mobile/Package.swift; ADR-0031. |
| 2.6 | Deployment target iOS 18 (= the iPhone 16 generation), up to the newest device the framework supports. The foldable-native APIs (availability 27.1) are reached through @available, with a size-class layout as the fallback. | Mobile/Package.swift; ADR-0030. |
| 2.7 | Project format: the .ws library stays on the Mac. The device holds no authoritative library. | §3. |
| 2.8 | Tests: Swift Testing (`import Testing`). Legacy XCTest files stay; add none. | Tests/. |
| 2.9 | Version: three digits, middle = phase, third = hotfix. | Boss ruling. |
| 2.10 | Project root: /Volumes/ANAN/Engineering/wenshu/ (the client at Mobile/). | Canonical. |
| 2.11 | The shell is iOS's own: a TabView with a tab bar, a NavigationStack inside each tab, and a NavigationSplitView only where the regular width earns it. A phone never shows a sidebar. | ADR-0033. |
| 2.12 | The chrome is the system's, and it gets there by using the system's own components, not by imitating an app: the system tab bar, the glass surfaces (`.glassEffect(.regular, in:)` inside a `GlassEffectContainer`), the glass buttons (`.buttonStyle(.glass)`), semantic colours, ContainerRelativeShape corners, the navigation bar's large title, a section header built from Text and NavigationLink. No hand-drawn tab bar, shadow, corner radius or hex value. Dark mode is a first-class case. | ADR-0033. |

## §3 Product-line boundary (the Mac owns the library)

> The phone is a remote control first and a reader second. It is never a second writer.

| #   | Fact | Reference |
| --- | ---- | --------- |
| 3.1 | The authoritative body text and the .ws store live on the Mac. The device reads a projection and sends commands. | Mobile/docs/product-line-plan.md 3.4. |
| 3.2 | The Mac is the single writer in the first release. A device write is a command the Mac applies, not a local edit. | Mobile/docs/product-line-plan.md 3.1. |
| 3.3 | Reachability is a tunnel, not a hosted service this project runs: the Mac dials out, the device pairs. | Mobile/docs/product-line-plan.md 3.2. |
| 3.4 | Every byte of body text is end-to-end encrypted by the app layer. A tunnel that terminates TLS is transport only. | Mobile/docs/product-line-plan.md 3.3. |
| 3.5 | A device that cannot reach the Mac shows that fact; it never shows a stale library as if it were current. | Mobile/docs/product-line-plan.md 3.4. |
| 3.6 | The device never writes into the .ws tree. Sync writes the Mac-side canonical copy only. | Mobile/docs/product-line-plan.md 3.4. |
| 3.7 | The link contract lives in WenshuMobileKit until a second consumer needs it, then it moves to the shared repository pinned by version. A second copy of a type the kit owns is a defect. | ADR-0031. |

## §4 Device-local persistence

> Device state is a cache and a draft area, never a second library.

| #   | Fact | Reference |
| --- | ---- | --------- |
| 4.1 | SwiftData on the device holds drafts, session state and a read cache. It is disposable: clearing it loses nothing the Mac cannot resend. | Mobile/Sources/WenshuMobileKit. |
| 4.2 | The canonical reference copy is the Mac-side file tree. A cached copy is a projection, with the source revision it came from. | Mobile/docs/product-line-plan.md 2.4. |
| 4.3 | Credentials and pairing keys live in the Keychain, never in the SwiftData store. | Mobile/Package.swift; Apple Keychain. |
| 4.4 | A draft carries the revision it was based on. The Mac rejects a write against a moved revision and says so. | Mobile/docs/product-line-plan.md 3.4. |

## §5 Third-party library policy

> Default = Apple stack exclusive. Exceptions require a 4-gate pass.

| #   | Fact | Reference |
| --- | ---- | --------- |
| 5.1 | Default: Apple stack only. Mobile/Sources/ imports only Apple frameworks and the local packages. | Mobile/Package.swift; manual review. |
| 5.2 | Third-party exceptions need ALL 4: (a) >=100 stars, (b) commit <=12 months, (c) MIT/Apache/BSD/PD, (d) iOS-supported. | Boss ruling 8/27 (OOB.md). |
| 5.3 | Icons = SF Symbols (built-in, zero SPM). NEVER lucide-swift. One icon factory, one token file. | Tools/wenshu-devtool/design-sweep.sh. |
| 5.4 | Approved deps (= the repository's upstreams.json, regenerated by upstreams-scan.py): the CLIENT has none; the desktop's four are not the client's. | upstreams.json. |
| 5.5 | New dep: 1-page rationale + the 4 gates in 5.2 + a boss ruling. Then upstreams-scan.py regenerates upstreams.json. | OOB.md. |

## §6 Project structure (canonical target)

> One feature = one self-contained folder. Apple Backyard Birds template.

| #   | Fact | Reference |
| --- | ---- | --------- |
| 6.1 | Mobile/Sources/ = 2 SwiftPM targets: WenshuMobileApp/ (executable: App/ + Features/<Name>/ + Shared/) and WenshuMobileKit/ (library: the link contract, no views). Mobile/Tests/ = the test target. | Mobile/Package.swift. |
| 6.2 | A feature folder uses up to 4 slots: Model/ + Service/ + Store/ + View/. A feature carries only the slots it needs. | Mobile/Sources/WenshuMobileApp/Features. |
| 6.3 | Cross-feature code lives in Mobile/Sources/WenshuMobileApp/Shared/; the link model both sides agree on lives in Mobile/Sources/WenshuMobileKit/. | Shared/; WenshuMobileKit. |
| 6.4 | File naming suffix by role: <Xxx>View / <Xxx>Ops / <Xxx>Service / <Xxx>State .swift. One concern per file. | wenshu-swift-standards.md §1.2. |
| 6.5 | File size cap: 600 LOC per .swift file. Exceed = split, and register the split in the NFI (1.7). | wenshu-swift-standards.md §1.2. |
| 6.6 | One import block per file. Alphabetical. No unused imports. | wenshu-swift-standards.md §1.1. |
| 6.7 | Single-purpose rule. Any dir with exactly 1 file and 0 dependents = deletion candidate (= a scratch spec; = a per-decision ADR). | Boss OOB 2026-10-16. |
| 6.8 | Top-level purpose map. Mobile/Sources/ = Swift targets (canonical). Mobile/Tests/ = Swift test target. Mobile/docs/ = the product line plan. Tools/wenshu-devtool/ = gates. docs/adr/ + docs/agents/ = the shared decision record + governance docs. | Boss OOB 2026-10-16. |
| 6.9 | The device gate scripts are a port of the desktop ones. The desktop copy is the semantic SSOT; a change to a gate lands in both repos in the same ticket. | Tools/wenshu-devtool/README.md. |

## §7 Verification & quality gates

> Two classes. §7.1-§7.10 gate a landed diff. §7.11-§7.12 fire before the code exists.

### Merge-blocking gates (the diff must pass all ten)

| #   | Gate | Reference |
| --- | ---- | --------- |
| 7.1 | swift build exits 0, and the iOS build exits 0. | CI; Scripts/setup-dev-env.sh. |
| 7.2 | swift test exits 0. No skipped test without // TODO + tracker id. | CI (swift test). |
| 7.3 | Design sweep: zero naked Image(systemName:), zero inline .cornerRadius(N), zero .font(.system(size:)), zero magic spacing in the changed view files. One icon factory and one token file own those values. | Tools/wenshu-devtool/design-sweep.sh. |
| 7.4 | Dual-axis audit: Standards axis (code-review + codebase-design) + Spec axis (the card's 4-section spec). Both read-only, parallel. | docs/agents/parallel-development.md; wenshu-parallel-dev. |
| 7.5 | CJK comment audit: zero new CJK in the modified file. Manual: CI checks the commit subject only. | CI lint-commits job. |
| 7.6 | No dead code. | Tools/wenshu-devtool/verify-dead.py. |
| 7.7 | UI-touching ticket: the boss looks at the running build in person. A screenshot is evidence only when asked. The worker's GUI drive = the `computer_use` tool (Hermes' built-in front for the cua-driver MCP server) in background delivery: never synthetic mouse/keyboard events, never the user's cursor or foreground. Headless checks are preferred. | OOB.md. |
| 7.8 | Commit hygiene: 1 commit per ticket, conventional prefix, English subject, body explains WHY. | CI lint-commits job; commit_filter.py commit-msg hook. |
| 7.9 | Independent review verdict: the REVIEWER ends with `kanban_complete(metadata={"review_outcome": "approved"})` = the field the gate reads, so a verdict in the summary alone is NO verdict, and it is never backfilled by hand. `Scripts/merge-preflight.sh` refuses the merge without one. | Tools/wenshu-devtool/review_gate.py. |
| 7.10 | Named narrow gate: a card's body names the filtered suite that owns each file it writes, as a `swift test --filter <Suite>` command (a card with no Swift code names its own gate command). A T1/T2 card never asks for the whole suite. Naming no gate is a defect. | Tools/wenshu-devtool/gate_width_gate.py. |

### Intake and dispatch gates (they fire before the code exists)

| #   | Gate | Reference |
| --- | ---- | --------- |
| 7.11 | Evidence budget: this gate checks rule 1.15's four lines AND the order shape (line-numbered seams, one writer per file) before a worker starts (a gate inside a card costs a re-run). A card that reads without a budget is a defect. | Tools/wenshu-devtool/effort_budget_gate.py. |
| 7.12 | Fan-out budget: a card that opens sub-agents names disjoint scopes, one writer per file, and the parent's total call ceiling. Duplicate scopes, duplicate goals and cold-cache children are reported: Hermes does not dedupe, share a cache or set a parent budget, so the card must. | Tools/wenshu-devtool/session_effort_audit.py. |

## §8 Workflow (universal PO methodology)

> One ticket = §8.1 -> §8.10 in order. Skip = fail. §8.1 prices the card before a worker reads; §8.6 prices the fan-out before it opens.

| #   | Step | Skill |
| --- | ---- | ----- |
| 8.1 | Evidence budget: name the read list, stop condition, forbidden lookups and deliverable. The research happens BEFORE the card, so the card is an order. | rule 1.15; Tools/wenshu-devtool/effort_budget_gate.py. |
| 8.2 | Design card: the Apple canonical API, the target shape, the stop condition. One page. | wenshu-apple-api-first. |
| 8.3 | 4-section business-language spec (business / current state / Apple canonical / after-fix). The Apple-canonical section IS the design card from 8.2, never a restatement. | wenshu-pocock-workflow + universal-pocock-workflow. |
| 8.4 | Code + smoke test + reproduce, in a worktree (board card, rule 1.12). | diagnosing-bugs; wenshu-parallel-dev. |
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
| Product line and architecture plan | Mobile/docs/product-line-plan.md |
| Swift standards + AI self-check | wenshu-pocock-workflow/references/wenshu-swift-standards.md |
| PO methodology | universal-pocock-workflow/SKILL.md |
| Apple HIG canonical | wenshu-apple-api-first/SKILL.md |
| Iron rules audit (Apple HIG + Swift rules) | wenshu-iron-rules-audit/SKILL.md |
| Visual audit | wenshu-visual-audit/SKILL.md |
| Parallel dev convention (worktree board cards) | wenshu-parallel-dev/SKILL.md |
| Parallel dev contract (in-repo) | docs/agents/parallel-development.md |
| Nervous file index (NFI) | docs/agents/nfi.md |
| Ticket difficulty tiers | docs/agents/ticket-tiers.md |
| Domain glossary | docs/agents/domain.md |
| Devtool gates + scripts | Tools/wenshu-devtool/README.md |
| OOB index (boss directives, dev-time only) | OOB.md |
| Project identity note (dev-time only) | Mobile/IDEA.md |
| ADRs (0029-0033) | docs/adr/ |
| Native client, Mac authority | docs/adr/0029-native-client-and-mac-authority.md |
| Deployment floor + foldable fallback | ADR-0030 |
| Kit placement + the shared repository | ADR-0031 |
| Device priority (the iPhone 18 family, the foldable adapts) | ADR-0032 |
| The iOS-native shell (tab bar, stack, split) | ADR-0033 |
| Desktop repo (the macOS app) | AGENTS.md |

## §10 Change protocol for THIS file

> AGENTS.md is SSOT. Touch with care.

| #   | Rule |
| --- | ---- |
| 10.1 | Edit trigger = boss OOB only. Never edit during a normal ticket. |
| 10.2 | New rule = add numbered row (§1.X / §2.X / etc.). Never insert between rows. |
| 10.3 | Remove rule = delete from this file. No history. Outdated = gone. |
| 10.4 | Pre-flight before committing this file: `python3 Tools/wenshu-devtool/agents_gate.py --file AGENTS.md` exits 0. It checks the frontmatter parses, the file fits the loader's 20,000-char cap (= the whole file, frontmatter included), every named path and skill exists, the rule ids are contiguous, and no CJK hides outside 1.2-1.4. |

> First line fact: Wenshu Mobile is a Swift / SwiftUI iOS and iPadOS client that drives the Mac app.
> Last line fact: This file is SSOT for wenshu-mobile; all detail lives in §9 reference index.
