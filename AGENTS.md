---
name: wenshu-agents
description: Wenshu SSOT hard rules + project baseline. Load on every wenshu turn.
version: 3.2.0
license: MIT
platforms: [macos]
metadata:
  hermes:
    tags: [wenshu, ssot, hard-rule]
    default_on: true
    category: policy
    note: "SSOT. English-only. 1-3 lines per rule. No narrative."
related_skills: [wenshu-pocock-workflow, wenshu-parallel-dev, wenshu-apple-api-first]
---

# AGENTS.md — Wenshu SSOT

SSOT for every contributor and agent on /Volumes/ANAN/Engineering/wenshu.

## §0 Load order (read on every wenshu turn)

> Order matters. Skip = silent drift.

1. AGENTS.md (this file) — 10 sections of project SSOT (reached via the .hermes.md pointer; see 1.9).
2. ~/.hermes/shared/wenshu-skills/wenshu-pocock-workflow/SKILL.md — workflow entry.
3. ~/.hermes/shared/wenshu-skills/wenshu-pocock-workflow/references/wenshu-swift-standards.md — Swift standards.
4. .scratch/<date>-<topic>/spec.md if a ticket is open.
5. OOB.md if any rule references (see OOB.md #YYYY-MM-DD).

## §1 Hard rules (project-wide, non-negotiable)

> The rules with a machine gate block the commit. A rule whose cell says Manual has no gate.

| #   | Rule | Enforcement |
| --- | ---- | ----------- |
| 1.1 | English-only in code, comments, commits, prompts, all .md. No CJK characters. | CI lint-commits job (no CJK in the subject); the xianxia family by commit_filter.py + SwiftLint. Comment-level CJK is manual (770 CJK comment lines in Sources/ at commit d44c2df39, counted with the gate's regex). |
| 1.2 | Sole address for the user = "老板". No other forms. | Manual. commit_filter.py permits the project literals (老板 / 文枢 / 拍 / 拍板 / ※). |
| 1.3 | Forbidden hedges (replace with yes/no/yes-yes): 可 / 应当 / 或许 / 可能 / 应该 / 建议 / 考虑 / 试图 / 尽量 / 大概 / 也许 / 或 / 任意 / 大概率 / 通常 / 一般来说. | Manual (= no machine gate). |
| 1.4 | Forbidden xianxia vocabulary (replace with 修 / 改 / fix / 替换 / 调整): 修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹 / 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障. | commit_filter.py (pre-commit + commit-msg + pre-push hooks in .git/hooks/) + .swiftlint.yml xianxia_forbidden_vocab (severity error) + CI Pollution check. |
| 1.5 | Comment policy: engineering intent only. Forbidden: boss directive text, ticket IDs, Q-numbers, version narratives, phase numbering, refactor history, ticket lineage. | Manual. |
| 1.6 | OOB references in code: only (see OOB.md #YYYY-MM-DD). Never directive text inline. | Manual. |
| 1.7 | NFI registration: every extracted or added file MUST be registered in `docs/agents/nfi.md` with parent ref + LOC + content tag. Discoverable < 5s by name. Register a new row there, not here. | Manual. |
| 1.8 | High information density. One line per argument. No narrative paragraphs. | Manual; shape = to-spec. |
| 1.9 | Load chain: .hermes.md at the repo root is the file Hermes injects (it wins over AGENTS.md) and points here + at the skill chain. A skill body loads on demand via skill_view; only its description is injected. | .hermes.md. `skills.auto_load` in config.yaml injects a body; a frontmatter `default_on` does not. |
| 1.10 | One ticket = one commit + one atomic verification + one 4-section spec + one dual-axis dispatch + one P0 fix + one verify round + merge gate. | Tools/wenshu-devtool/ticket_tier.py; Scripts/merge-preflight.sh. |
| 1.11 | The NFI registry = `docs/agents/nfi.md`: one row per extracted or added file, append-only. `merge=nfi-registry` in .gitattributes merges two cards' rows at the key level. | docs/agents/nfi.md. |
| 1.12 | Parallel worktree isolation: every code-changing ticket runs in its own git worktree, never the shared checkout (= a kanban card, `--workspace worktree --project project`, board `wenshu-par`). `delegate_task` is read-only fan-out here: its children inherit the parent cwd, so a relative write lands in the shared checkout. | wenshu-parallel-dev. |
| 1.13 | Difficulty tier: every card carries a tier (`[T1]` / `[T2]` / `[T3]`), DERIVED by `Tools/wenshu-devtool/ticket_tier.py` from the work its body describes, never hand-set. The tier sets the runtime cap, retry budget, gate width and body budget = cost, not quality: it never skips the dual-axis review, never marks a test skipped. | ticket_tier.py; ticket-tiers.md. |
| 1.14 | Independent review: a card that writes CODE carries a `## REVIEW HANDOFF` naming a reviewer profile that is NOT its implementer, and ends with `kanban_request_review(reviewer=...)`. The obligation is DERIVED from the work the body describes, never the tier. A prose-only card owes no verdict. | review_gate.py; Scripts/merge-preflight.sh. |
| 1.15 | Evidence before code: a card that reads names its read list, stop condition, forbidden lookups and deliverable in an `## EVIDENCE BUDGET` section. Reading is a cost like a build, and it burns first. | Tools/wenshu-devtool/effort_budget_gate.py (the gate is 7.11). |

## §2 Stack baseline

> Lock these. New framework requires a boss ruling.

| #   | Fact | Reference |
| --- | ---- | --------- |
| 2.1 | Stack: Swift / SwiftUI / Observation (@Observable) / SwiftData / Swift Concurrency. | Apple stack exclusive. |
| 2.2 | NO CoreData. NO SQLite (SwiftData only). NO external AI platform SDK. NO monorepo. NO npm. NO Python in the app target. NO Rust. NO Tauri. NO Vue. | Package.swift (tools-version 6.4); Sources/ imports = Apple frameworks + 4 approved upstreams. |
| 2.3 | macOS-only. iPad/iPhone code supported but NOT target. | Boss ruling 8/18. |
| 2.4 | Swift 6 strict concurrency. @MainActor for UI. actor for background. Sendable for cross-isolation. | wenshu-swift-standards.md §4; ADR-0027 (each @unchecked Sendable justified; its count is its census at its date). |
| 2.5 | LLM connector: 14 slugs = 13 built-in + custom (anthropic / openai-codex / gemini / deepseek / ollama / openrouter / minimax / minimax-cn / nous / copilot / copilot-acp / xai-oauth / stepfun / custom). BYOK, no default. | Sources/WenshuAgent/Sources/WenshuAgent/Connector/BuiltInProviders.swift. |
| 2.6 | LLM key storage: macOS Keychain via ProviderKeychain, AND a plaintext mirror at `~/Library/Application Support/com.wenshu.app/provider-keys.json` (mode 0600, outside the .ws). Normally every write hits BOTH stores and the toggle picks the read primary; the debug no-keychain override writes the file only. NEVER inside the .ws. | Sources/WenshuAgent/Sources/WenshuAgent/Keychain/MirroredKeychainStore.swift. |
| 2.7 | Project format: .ws package (single-process, per-user local). | §3. |
| 2.8 | Tests: Swift Testing (`import Testing`). Legacy XCTest files stay; add none. | Tests/. |
| 2.9 | Version: three digits, middle = phase, third = hotfix. | Boss ruling. |
| 2.10 | Project root: /Volumes/ANAN/Engineering/wenshu/. | Canonical. |

## §3 .ws library model

> One user = one library. Default root = ~/Documents/wenshu.

| #   | Fact | Reference |
| --- | ---- | --------- |
| 3.1 | First launch opens a `.fileImporter` restricted to the .ws package type (NEVER a raw NSOpenPanel modal). A picked folder with no Info.plist is created as a .ws by that importer. | Sources/WenshuApp/Shared/UI/LibraryRootView.swift. |
| 3.2 | The choice is persisted as a bookmark (`url.bookmarkData`), with `.withSecurityScope` in sandboxed builds only. NOT a raw path string. NOT a UserDefaults string. | Sources/WenshuApp/Features/Library/Store/LibraryBookmark.swift (key `wenshu.libraryBookmark`). |
| 3.3 | CFBundlePackageType = WSPC for .ws packages. | Features/Library/Service/LibraryBootstrapper.swift; LibraryMigrator.swift. |
| 3.4 | The legacy UserDefaults key `wenshu.libraryPath` is dropped once at launch; the bookmark is the sole persistence and `ActiveLibrary.path` is the only accessor. | Sources/WenshuApp/App/WenshuAppDelegate.swift. |
| 3.5 | Switching library posts `com.wenshu.library.didChange`; the next read resolves the new library. | Sources/WenshuApp/App/AppNotifications.swift. |
| 3.6 | Per-book structure: shelves/<shelf-uuid>/books/<book-uuid>/ with 7 standard folders (world / characters / outlines / chapters / drafts / ideas / sessions). Per-book JSON at the book-dir root: book / chapters / entities / outlines / kanban / todo / drafts (.json). shelf.json per shelf; reference-library/library.json. | BookFolderCatalog.swift. |
| 3.7 | Reference-library: ONE instance per .ws at reference-library/, with 2 layers (raw / entities) plus library.json metadata. The user CAN rename and delete individual references (the library root is not user-deletable). | Features/Library/Model/Reference.swift; FileSystemReferenceStore.swift; AppleSidebarView.swift. |

## §4 Persistence (SwiftData canonical)

> One store = one ModelContainer. 21 @Model classes. No duplication.

| #   | Fact | Reference |
| --- | ---- | --------- |
| 4.1 | Two accessors, one container: `WSPersistenceContainer.shared` (Application Support, lazily built) and `WSPersistenceContainer.current` (the warehouse container when one is active, else `shared`). New callers use `current`. | Sources/WenshuData/Sources/WenshuData/Container.swift. |
| 4.2 | 21 @Model classes in Schema([...]), grouped across WS*.swift files (not one class per file). | Sources/WenshuData/Sources/WenshuData/Container.swift. |
| 4.3 | 7 domain repositories (memory / chat / todo / kanban / link / providerKey / preference) wrap 10 of the 21 models; the other 11 are read directly off the container. Each exposes a `.shared` singleton; WSRepositoryContainer bundles all 7. | Sources/WenshuData/Sources/WenshuData/Repositories/WSRepositoryContainer.swift. |
| 4.4 | Migration: ModelsSchemaV1 (VersionedSchema). Additive changes need no plan; a non-additive one (rename, type change, cardinality flip) requires a declared next version. | Sources/WenshuData/Sources/WenshuData/ModelsSchema.swift. |
| 4.5 | Cross-isolation Sendable: @Model classes Sendable by SwiftData inference. Background writes via ModelActor or @MainActor repos, never a detached task on the context. | wenshu-swift-standards.md §4. |
| 4.6 | Search: Core Spotlight (CSSearchableIndex + CSSearchQuery). NO GRDB / NO FTS5. | Features/Library/Service/CSSearchableIndexSearch.swift. |

## §5 Third-party library policy

> Default = Apple stack exclusive. Exceptions require a 4-gate pass.

| #   | Fact | Reference |
| --- | ---- | --------- |
| 5.1 | Default: Apple stack only. Sources/ imports only Apple frameworks, the 4 approved upstreams (5.4), and the local packages WenshuAgent / WenshuData. | Package.swift; manual review. |
| 5.2 | Third-party exceptions need ALL 4: (a) >=100 stars, (b) commit <=12 months, (c) MIT/Apache/BSD/PD, (d) macOS-supported. | Boss ruling 8/27 (OOB.md). |
| 5.3 | Icons = SF Symbols 6 (built-in, zero SPM). NEVER lucide-swift. SFIcon / IconColor / IconStyle live in the one icon factory. | Sources/WenshuApp/Shared/UI/IconStyles.swift. |
| 5.4 | Approved deps (= upstreams.json, regenerated by upstreams-scan.py): swift-markdown-engine 0.13.x (Apache-2.0), HighlighterSwift 3.1.0 (MIT), EventSource 1.5.1 (MIT). Test-only: ViewInspector 0.10.3 (MIT). | upstreams.json; Tools/wenshu-devtool/upstreams-scan.py. |
| 5.5 | New dep: 1-page rationale + the 4 gates in 5.2 + a boss ruling. Then upstreams-scan.py regenerates upstreams.json. | OOB.md. |

## §6 Project structure (canonical target)

> One feature = one self-contained folder. Apple Backyard Birds template.

| #   | Fact | Reference |
| --- | ---- | --------- |
| 6.1 | Sources/ = 3 SwiftPM targets: WenshuApp/ (executable: App/ + Features/<Name>/ + Shared/), plus 2 local path packages WenshuData/ (store) and WenshuAgent/ (agent runtime). | Package.swift |
| 6.2 | A feature folder uses up to 4 slots: Model/ + Service/ + Store/ + View/. A feature carries only the slots it needs (Kanban = no Store/, Outline = no Service/ or Store/). The 5-slot form in the standards doc is deferred (ADR-0025). | Sources/WenshuApp/Features |
| 6.3 | A migration arc (>=5 tickets) renames top-level dirs feature-by-feature, one feature + one commit per ticket. | universal-pocock-workflow. |
| 6.4 | Cross-feature code lives in Sources/WenshuApp/Shared/<Name>/ (inside the app package). The package boundary is the 3 local targets, not a Shared package. | Shared/. |
| 6.5 | File naming suffix by role: <Xxx>View / <Xxx>Ops / <Xxx>Service / <Xxx>State .swift. One concern per file. | wenshu-swift-standards.md §1.2. |
| 6.6 | File size cap: 600 LOC per .swift file. Exceed = split, and register the split in the NFI (1.7). DEFERRED (ADR-0025). | wenshu-swift-standards.md §1.2. |
| 6.7 | One import block per file. Alphabetical. No unused imports. | wenshu-swift-standards.md §1.1. |
| 6.8 | Root tree (measured 2026-10-28): 6 visible dirs (Scripts / Sources / Tests / Tools / build / docs), 13 hidden dirs, 10 visible files, 7 hidden files. .worktrees/ = card worktrees. .test-backup-x-*/ + .test-vision-*.txt = gitignored sandbox copies (their count grows per test run, so it is not asserted). | Measured 2026-10-28. |
| 6.9 | Single-purpose rule. Any dir with exactly 1 file and 0 dependents = deletion candidate (= .scratch/ specs; = docs/agents/ per-role docs; = docs/adr/ per-decision docs). The 3 hidden tooling dirs (.claude/ .git-hooks/ .hermes/) hold one entry each by design. | Boss OOB 2026-10-16. |
| 6.10 | Top-level purpose map. Sources/ = Swift targets (canonical). Tests/ = Swift test target. Scripts/ = shell + python helpers. Tools/wenshu-devtool/ = gates + probes. build/ = swift build output (.gitignored). docs/ = adr/ + agents/. | Boss OOB 2026-10-16. |

## §7 Verification & quality gates

> Two classes. §7.1-§7.10 gate a landed diff. §7.11-§7.12 fire before the code exists.

### Merge-blocking gates (the diff must pass all ten)

| #   | Gate | Reference |
| --- | ---- | --------- |
| 7.1 | swift build exits 0. | Scripts/build-app.sh; CI |
| 7.2 | swift test exits 0. No skipped test without // TODO + tracker id. | CI (swift test). |
| 7.3 | 9-grep design sweep (icon glyph / spacing / cornerRadius / shadow / font long-form / color opacity / frame max-W/H / imageScale / SFIcon color). Each must return 0 on the changed view files. Enforced by 22 sweep suites in Tests/WenshuAppTests/UI/DesignSystem (swift test), never by the pre-commit hook. | references/v3.0-design-system-rule.md. |
| 7.4 | Dual-axis audit: Standards axis (code-review + codebase-design) + Spec axis (.scratch/<date>-<topic>/spec.md). Both read-only, parallel. | parallel-development.md; wenshu-parallel-dev. |
| 7.5 | CJK comment audit: zero new CJK in the modified file. Manual: CI checks the commit subject only; no comment-level CJK gate ships in the tree. | CI lint-commits job |
| 7.6 | No dead code. | verify-dead.py. |
| 7.7 | UI-touching ticket: the boss looks at the running build in person. A screenshot is evidence only when asked. | wenshu_devtool.py. |
| 7.8 | Commit hygiene: 1 commit per ticket, conventional prefix, English subject, body explains WHY. | CI lint-commits job (prefix + no CJK in the subject); commit_filter.py commit-msg hook. |
| 7.9 | Independent review verdict: a card that writes code carries an approving verdict from a profile that is NOT its implementer (rule 1.14). `Scripts/merge-preflight.sh` refuses the merge without it. | review_gate.py. |
| 7.10 | Named narrow gate: a card's body names the filtered suite that owns each file it writes, as a `swift test --filter <Suite>` command (a card with no Swift code names its own gate command). A T1/T2 card never asks for the whole suite. Naming no gate is a defect. | gate_width_gate.py |

### Intake and dispatch gates (they fire before the code exists)

| #   | Gate | Reference |
| --- | ---- | --------- |
| 7.11 | Evidence budget: the four lines (read / stop when / no / deliver) are defined in rule 1.15; this gate checks them when the card enters the board. A card that reads without a budget is a defect. KNOWN GAPS: a bulleted read list counts as 1 file (the 12-file cap is evadable); a mistyped --board audits the default board. | effort_budget_gate.py. |
| 7.12 | Fan-out budget: a card that opens sub-agents names disjoint scopes, one writer per file, and the parent's total call ceiling. Duplicate scopes, duplicate goals and cold-cache children are reported: Hermes does not dedupe, share a cache or set a parent budget, so the card must. KNOWN GAPS: the counts over-count (the parent's reads, a rejected batch). | session_effort_audit.py. |

## §8 Workflow (universal PO methodology)

> One ticket = §8.1 -> §8.10 in order. Skip = fail. §8.1 prices the card before a worker reads; §8.6 prices the fan-out before it opens.

| #   | Step | Skill |
| --- | ---- | ----- |
| 8.1 | Evidence budget: name the read list, stop condition, forbidden lookups and deliverable. | rule 1.15; effort_budget_gate.py. |
| 8.2 | Design card: the Apple canonical API, the target shape, the stop condition. One page. | wenshu-apple-api-first. |
| 8.3 | 4-section business-language spec (business / current state / Apple canonical / after-fix). The Apple-canonical section IS the design card from 8.2, never a restatement. | wenshu-pocock-workflow + universal-pocock-workflow. |
| 8.4 | Code + smoke test + reproduce, in a worktree (board card, rule 1.12). | diagnosing-bugs; wenshu-parallel-dev. |
| 8.5 | Real violation inventory (read-only): the grep inventory of the affected area, by rule. | §7.3. |
| 8.6 | Fan-out budget: disjoint scopes, one writer per file, the parent's call ceiling, one shared evidence pack. | rule 7.12; session_effort_audit.py. |
| 8.7 | Dual-axis dispatch (Standards + Spec, 2 parallel read-only sub-agents). | code-review; codebase-design. |
| 8.8 | Fix P0. | universal-pocock-workflow step 5. |
| 8.9 | Verify round over the files the fix commit touched. | universal-pocock-workflow step 6. |
| 8.10 | Merge gate (boss verdict for UI; swift build for non-UI). | Scripts/merge-preflight.sh. |

## §9 Reference index (NOT duplicated here)

> Link, do not restate. SSOT = this-file-row. A bare tool name = that tool under `Tools/wenshu-devtool/`; a bare skill name = its skill dir; every other path is repo-relative.

| Topic | Link |
| ----- | ---- |
| Swift standards + AI self-check | wenshu-pocock-workflow/references/wenshu-swift-standards.md |
| PO methodology | universal-pocock-workflow/SKILL.md |
| Apple HIG canonical | wenshu-apple-api-first/SKILL.md |
| Design system rule (SFIcon, DesignTokens, 9-grep sweep) | wenshu-pocock-workflow/references/v3.0-design-system-rule.md |
| Iron rules audit (41 Apple HIG + Swift rules) | wenshu-iron-rules-audit/SKILL.md |
| Visual audit | wenshu-visual-audit/SKILL.md |
| Parallel dev convention (worktree board cards) | wenshu-parallel-dev/SKILL.md |
| Parallel dev contract (in-repo) | docs/agents/parallel-development.md |
| Nervous file index (NFI) | docs/agents/nfi.md |
| Ticket difficulty tiers | docs/agents/ticket-tiers.md |
| Devtool gates + probes | Tools/wenshu-devtool/README.md |
| OOB index (boss directives, dev-time only) | OOB.md |
| Domain glossary | docs/agents/domain.md |
| ADRs (0000-0027) | docs/adr/ |
| Deferred standards (6.2 + 6.6) | docs/adr/0025-*.md |
| Unchecked-Sendable audit | docs/adr/0027-*.md |

## §10 Change protocol for THIS file

> AGENTS.md is SSOT. Touch with care.

| #   | Rule |
| --- | ---- |
| 10.1 | Edit trigger = boss OOB only. Never edit during a normal ticket. |
| 10.2 | New rule = add numbered row (§1.X / §2.X / etc.). Never insert between rows. |
| 10.3 | Remove rule = delete from this file. No history. Outdated = gone. |
| 10.4 | Pre-flight before committing this file: `python3 Tools/wenshu-devtool/agents_gate.py --file AGENTS.md` exits 0. It checks the frontmatter parses, the file fits the loader's 20,000-char cap (= the whole file, frontmatter included), every named path and skill exists, the rule ids are contiguous, and no CJK hides outside rules 1.2 / 1.3 / 1.4. |

> First line fact: Wenshu is a Swift / SwiftUI / SwiftData macOS app, single-process, Apple-stack exclusive.
> Last line fact: This file is SSOT for wenshu; all detail lives in §9 reference index.
