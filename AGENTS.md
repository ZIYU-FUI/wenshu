---
name: wenshu-agents
description: Wenshu SSOT hard rules + project baseline. Load on every wenshu turn.
version: 3.1.0
license: MIT
platforms: [macos]
metadata:
  hermes:
    tags: [wenshu, ssot, hard-rule]
    default_on: true
    category: policy
    note: "v3.1 governance. Replaces AGENTS.md v2 + CLAUDE.md + AGENTS-§11-rules.md + AGENTS-§11-history.md. SSOT. English-only. 1-3 lines per rule. No narrative, no version history, no ticket lineage."
related_skills:
  - wenshu-pocock-workflow
  - wenshu-apple-api-first
  - wenshu-pollution-defense
  - wenshu-comment-policy
  - wenshu-commit-history-hygiene
  - wenshu-iron-rules-audit
  - pocock-engineering-design-check
---

# AGENTS.md — Wenshu SSOT

Single source of truth for every wenshu contributor and every AI agent acting on /Volumes/ANAN/Engineering/wenshu. All sections English-only, 1-3 lines per rule, no narrative.

## §0 Load order (read on every wenshu turn)

> Order matters. Skip = silent drift.

1. AGENTS.md (this file) — 10 sections of project SSOT.
2. ~/.hermes/profiles/pocock/skills/wenshu-pocock-workflow/SKILL.md — workflow entry + auto-load chain.
3. ~/.hermes/profiles/pocock/skills/wenshu-pocock-workflow/references/wenshu-swift-standards.md — Swift standards + AI self-check.
4. .scratch/<date>-<topic>/spec.md if a ticket is open.
5. OOB.md if any rule references (see OOB.md #YYYY-MM-DD).

## §1 Hard rules (project-wide, non-negotiable)

> Violations block the commit. Pre-commit hooks enforce.

| #   | Rule | Enforcement |
| --- | ---- | ----------- |
| 1.1 | English-only in code, comments, commits, prompts, all .md. No CJK characters. | .hermes/cjk_comment_audit.txt pre-commit. |
| 1.2 | Sole address for the user = "老板". No other forms. | wenshu-pollution-defense. |
| 1.3 | Forbidden hedges (replace with yes/no/yes-yes): 可 / 应当 / 或许 / 可能 / 应该 / 建议 / 考虑 / 试图 / 尽量 / 大概 / 也许 / 或 / 任意 / 大概率 / 通常 / 一般来说. | wenshu-pollution-defense. |
| 1.4 | Forbidden xianxia vocabulary (replace with 修 / 改 / fix / 替换 / 调整): 修真 / 渡劫 / 筑基 / 返虚 / 结丹 / 金丹 / 元婴 / 飞升 / 天劫 / 雷劫 / 心魔 / 魔障. | wenshu-pollution-defense. |
| 1.5 | Comment policy: engineering intent only. Forbidden: boss directive text, ticket IDs, Q-numbers, version narratives, phase numbering, refactor history, follow-up chains, ticket lineage. | wenshu-comment-policy. |
| 1.6 | OOB references in code: only (see OOB.md #YYYY-MM-DD). Never directive text inline. | Manual. |
| 1.7 | Nervous file index (NFI) registration: every extracted/added file (god-class split, scope views, helper namespace) MUST be registered in `docs/agents/nfi.md` with parent ref + LOC + content tag. Discoverability < 5s by name. | Manual. |
| 1.8 | High information density. One line per argument. No narrative paragraphs. | wenshu-humanizer-voice. |
| 1.9 | Auto-load wenshu-pocock-workflow on every wenshu turn (forced via .hermes.md at repo root). | Path-enforced. |
| 1.10 | One ticket = one commit + one atomic verification + one 4-section business-language spec + one dual-axis dispatch + one P0 fix + one verify round + merge gate. | universal-pocock-workflow. |
| 1.11 | NFI (nervous file index) = `docs/agents/nfi.md`. Lists every file split from a god-class or extracted to its own file via A55+ arcs. Each row: parent file, current LOC, content tag. The next reader finds the file by concern in < 5s. | Manual. |
| 1.12 | Parallel worktree isolation: every code-changing ticket runs in its own git worktree, never in the shared checkout. Create it as a kanban board card (`--assignee wenshu-dev --workspace worktree --project project`, board `wenshu-par`). `delegate_task` is read-only fan-out here: its children inherit the parent shell cwd, so a relative write lands in the shared checkout. | wenshu-parallel-dev. |
| 1.13 | Difficulty tier: every card carries a tier (`[T1]` / `[T2]` / `[T3]`), DERIVED from the work its body describes by `Tools/wenshu-devtool/ticket_tier.py`, never hand-set. The tier sets the runtime cap, the retry budget, the gate width and the body budget. It changes the cost of a card, never the quality bar: it never skips the dual-axis review and never marks a test skipped. | docs/agents/ticket-tiers.md. |

### §1.11 Nervous file index (NFI)

The registry itself lives in `docs/agents/nfi.md` (= one row per
extracted or added file: parent file, extracted file, current LOC,
content tag). It lives there because it is append-only: two cards
each adding one row both wrote the same last line in this file and
collided. In its own file it merges at the key level, so two cards'
rows both survive and a genuine disagreement still conflicts with
the key named.

Register a new row there, not here. The rule is unchanged.

## §2 Stack baseline

> Lock these. New framework requires boss拍.

| #   | Fact | Reference |
| --- | ---- | --------- |
| 2.1 | Stack: Swift / SwiftUI / Swift Observation (@Observable) / SwiftData / Swift Concurrency. | Apple stack exclusive. |
| 2.2 | NO CoreData. NO SQLite. NO external AI platform. NO monorepo. NO npm. NO Python. NO Rust. NO Tauri. NO Vue. | Single-platform Swift baseline. |
| 2.3 | macOS-only. iPad/iPhone code supported but NOT target. | Boss 8/18 拍. |
| 2.4 | Swift 6 strict concurrency. @MainActor for UI. actor for background. Sendable for cross-isolation. | wenshu-swift-standards.md §4. |
| 2.5 | LLM connector: 14 first-class + custom (Anthropic / OpenAI / Gemini / DeepSeek / Ollama / OpenRouter / minimax / minimax cn / Nous / OpenAI Codex / GitHub Copilot / Copilot ACP / xAI OAuth / StepFun). BYOK. No default. | Core/Provider/. |
| 2.6 | LLM key storage: macOS Keychain via AppleKeychain. NEVER plaintext. | Core/Auth/. |
| 2.7 | Project format: .ws package (single-process, per-user local). | §3. |
| 2.8 | Tests: Swift Testing + swift test. NO XCTest for new code. | Tests/. |
| 2.9 | Version: three digits, middle = phase, third = hotfix. | Boss拍. |
| 2.10 | Project root: /Volumes/ANAN/Engineering/wenshu/. | Canonical. |

## §3 .ws library model

> One user = one library. Persisted at ~/wenshu/<uuid>.ws.

| #   | Fact | Reference |
| --- | ---- | --------- |
| 3.1 | .ws opens via .fileImporter (NEVER NSOpenPanel modal). | wenshu-fcp-library-replica reference. |
| 3.2 | Apple-recommended persistence: security-scoped bookmark (url.bookmarkData(.withSecurityScope) + start/stopAccessingSecurityScopedResource). NOT raw path string. NOT session-only .fileImporter. | Apple HIG canonical. |
| 3.3 | CFBundlePackageType = WSPC for .ws packages. | Resources/Info.plist writer. |
| 3.4 | Onboarding: one-time, first launch. Two buttons: new library + open existing. Persists wenshu.libraryPath to UserDefaults. No re-prompt. | Views/Library/LibraryRootView.swift. |
| 3.5 | Switch library: Library Properties "Reset Library" clears UserDefaults + returns to onboarding. | §3.4. |
| 3.6 | Per-book structure: shelves/<shelf-uuid>/books/<book-uuid>/ with 8 folders (world / characters / outlines / chapters / drafts / sessions / foreshadowing / placeholders) + 5 book JSON + library-level JSON. | Storage/. |
| 3.7 | Reference-library: ONE instance, system-managed, user CANNOT delete or rename. Holds LLM Wiki 4 layers (raw / entities / abstracts / indexes). | §3.6. |

## §4 Persistence (SwiftData canonical)

> One store = one ModelContainer. 22 @Model classes. No duplication.

| #   | Fact | Reference |
| --- | ---- | --------- |
| 4.1 | Single ModelContainer via Persistence/Container.swift. Bootstrapped in WenshuAppDelegate.applicationDidFinishLaunching. | Container.swift:61-87. |
| 4.2 | 22 @Model classes in Schema([...]). Each in its own WS*.swift file. | Persistence/. |
| 4.3 | 8 domain repositories wrap @Model: WSRepositoryContainer. 14 @Model accessed directly via @Query. | Persistence/Repositories/. |
| 4.4 | Migration: .versionedSchema. No destructive in-place rewrites. | wenshu-swiftdata-migration-recipe. |
| 4.5 | Cross-isolation Sendable: @Model classes Sendable by SwiftData inference. Background writes via ModelActor or @MainActor repos. | wenshu-swift-standards.md §4. |
| 4.6 | Search: Core Spotlight (CSSearchableIndex + CSSearchQuery). NO GRDB / NO FTS5. | wenshu-iron-rules-audit. |

## §5 Third-party library policy

> Default = Apple stack exclusive. Exceptions require 4-gate pass.

| #   | Fact | Reference |
| --- | ---- | --------- |
| 5.1 | Default: Apple stack only. Sources/WenshuApp/ may NOT import outside Foundation / SwiftUI / AppKit / SwiftData / Observation / os / Security. | Manual review. |
| 5.2 | Third-party exceptions need ALL 4: (a) >=100 stars, (b) commit <=12 months, (c) MIT/Apache/BSD/PD, (d) macOS-supported. | §5.2 + boss 8/27 OOB. |
| 5.3 | Icons = SF Symbols 6 (built-in, zero SPM). NEVER lucide-swift. | UI/IconStyles.swift. |
| 5.4 | Approved runtime deps (ratified 2026-08-28): sindresorhus/Defaults 9.0.9, sindresorhus/KeyboardShortcuts 2.2.0, kean/Nuke + NukeUI, weichsel/ZIPFoundation 0.9.20, swiftlang/swift-markdown 0.4.0+, mattt/EventSource 1.5.1, gonzalezreal/Textual 0.5.0, apple/swift-log 1.15.0, smittytone/HighlighterSwift 3.1.0, witekbobrowski/EPUBKit 0.5.0, davecom/SwiftGraph 4.0.0, orchetect/MenuBarExtraAccess 1.3.0. | §5.4 verbatim. |
| 5.5 | New dep: 1-page rationale + run wenshu-adopt-third-party-package checklist. Boss拍 required. | wenshu-adopt-third-party-package. |

## §6 Project structure (canonical target)

> One feature = one self-contained folder. Apple Backyard Birds template.

| #   | Fact | Reference |
| --- | ---- | --------- |
| 6.1 | Target tree (after A arc migration): App/ (entry) + Features/<Name>/ (per feature) + Shared/<Name>/ (cross-feature) + Persistence/ (data). | Apple Backyard Birds / Food Truck. |
| 6.2 | Per-feature folder has 4 slots (Views/ / Model/ / Service/ / Store/) (= the project's actual Model+View+ViewModel+Service split = Apple Backyard Birds' shape adapted to wenshu). Empty slot allowed; = leaf features with <=3 files skip the Store/ slot. | pocock-engineering-design-check §1 SSOT. |
| 6.3 | A migration arc (>=5 tickets) renames top-level dirs feature-by-feature. Each ticket = exactly 1 feature migrated + 1 commit. | universal-pocock-workflow. |
| 6.4 | Shared code in Shared/<Name>/ as local SwiftPM package (Apple Backyard Birds pattern). | Shared/<Name>/Package.swift. |
| 6.5 | File naming: <Xxx>View.swift / <Xxx>Ops.swift / <Xxx>Service.swift / <Xxx>State.swift (= the project's actual suffixes). Suffixes non-negotiable. | wenshu-swift-standards.md §1.2. |
| 6.6 | File size cap: 600 LOC per .swift file. Exceed = god-class-field-drain-recipe or split. | wenshu-humanizer-voice. |
| 6.7 | One import block per file. Alphabetical. No unused imports. | wenshu-swift-standards.md §1.1. |
| 6.8 | Root-level tree: 6 visible dirs + 12 hidden dirs + 18 top-level files = canonical (post-2026-10-16 governance reset). Visible dirs: Scripts/ + Sources/ + Tests/ + Tools/ + build/ + docs/. Each has ONE purpose. Hidden dirs (.git / .git-hooks / .github / .hermes / .archive / .build / .claude / .hilo / .repowise / .scratch / .swiftpm / .test-backup-x-N/) either git-tracked (rule-defined) or .gitignore'd (no manual drift). Top-level files: AGENTS.md (SSOT) + Brewfile (dev env) + CHANGELOG.md (release notes) + CONTEXT.md (project context) + OOB.md (boss directives, dev-time only) + Package.swift (SwiftPM root) + Package.resolved (lockfile) + README.md (entry) + THIRD_PARTY_NOTICES.md (dep credits) + upstreams.json (deps inventory, generated by Tools/wenshu-devtool/upstreams-scan.py). Hidden files: .gitignore (rule list) + .hermes.md (Hermes autoload) + .swift-format + .swiftlint.yml (style) + .DS_Store (macOS noise) + .mcp.json (regen per-machine) + .test-vision-*.txt (sandbox scratch). | boss OOB 2026-10-16. |
| 6.9 | Single-purpose rule. Any dir containing exactly 1 file with 0 dependents = deletion candidate (= per-ticket spec lives in .scratch/; = per-role docs live in docs/agents/; = per-decision docs live in docs/adr/). No single-file dirs at root level. | boss OOB 2026-10-16. |
| 6.10 | Top-level purpose map. Sources/ = Swift app (canonical). Tests/ = Swift test target (= SwiftPM mirror of Sources/). Scripts/ = shell + python helpers + screenshot scripts (§7.7 visual proof gate). Tools/ = devtool + double-axis sweep (= §7.4). build/ = swift build output (.gitignored). docs/ = SSOT docs (= adr/ = decisions; = agents/ = per-role). All persistence/DX helpers in Scripts/. | boss OOB 2026-10-16. |

## §7 Verification & quality gates

> Each ticket passes §7.1-§7.8 BEFORE merge.

| #   | Gate | Reference |
| --- | ---- | --------- |
| 7.1 | swift build exits 0. | wenshu-app-build-pipeline. |
| 7.2 | swift test exits 0. NO skipped tests without // TODO + tracker id. | wenshu-stale-test-cleanup. |
| 7.3 | Pre-commit 9-grep sweep (icon glyph / spacing / cornerRadius / shadow / font long-form / color opacity / frame max-W/H / imageScale / SFIcon color). Each must return 0. | v3.0-design-system-rule.md. |
| 7.4 | Dual-axis audit: Standards axis (pocock-engineering-audit-existing) + Spec axis (.scratch/<date>-<topic>/spec.md §9). Both axes read-only. Parallel. | q99-dual-axis-wenshu-toolchain.md. |
| 7.5 | CJK comment audit: zero new CJK in modified file. | .hermes/cjk_comment_audit.txt. |
| 7.6 | No dead code: wenshu-dead-code-cleanup + verify-dead.py. | wenshu-dead-code-cleanup. |
| 7.7 | UI-touching ticket: visual proof via screenshot + boss verdict. | wenshu-agent-boss-same-build-protocol. |
| 7.8 | Commit hygiene: 1 commit per ticket, English subject <=72 chars, body explains WHY. | wenshu-commit-history-hygiene. |

## §8 Workflow (universal PO methodology)

> One ticket = §8.1 -> §8.7 in order. Skip = fail.

| #   | Step | Skill |
| --- | ---- | ----- |
| 8.1 | 4-section business-language spec (business / current state / Apple canonical / after-fix). | wenshu-pocock-workflow + universal-pocock-workflow. |
| 8.2 | Code + smoke test + reproduce, in a worktree (board card, rule 1.12). | diagnosing-bugs. |
| 8.3 | Real violation inventory. | q99-dual-axis-wenshu-toolchain.md. |
| 8.4 | Dual-axis dispatch (Standards + Spec, 2 parallel sub-agents, read-only). | q99-dual-axis-audit.md. |
| 8.5 | Fix P0. | universal-pocock-workflow step 5. |
| 8.6 | Verify round on fix-commits-touched files. | universal-pocock-workflow step 6. |
| 8.7 | Merge gate (boss verdict for UI; swift build for non-UI). | wenshu-pocock-workflow §merge-gate. |

## §9 Reference index (NOT duplicated here)

> Link, do not restate. SSOT = this-file-row.

| Topic | Link |
| ----- | ---- |
| Swift standards + AI self-check | ~/.hermes/profiles/pocock/skills/wenshu-pocock-workflow/references/wenshu-swift-standards.md |
| PO methodology | ~/.hermes/profiles/pocock/skills/universal-pocock-workflow/SKILL.md |
| Apple HIG canonical | ~/.hermes/profiles/pocock/skills/wenshu-apple-api-first/SKILL.md |
| Design system rule (SFIcon, DesignTokens, 9-grep sweep) | ~/.hermes/profiles/pocock/skills/wenshu-pocock-workflow/references/v3.0-design-system-rule.md |
| Iron rules audit (41 Apple HIG + Swift rules) | ~/.hermes/profiles/pocock/skills/wenshu-iron-rules-audit/SKILL.md |
| Parallel dev convention (worktree board cards) | ~/.hermes/profiles/pocock/skills/wenshu-parallel-dev/SKILL.md |
| Nervous file index (NFI) | /Volumes/ANAN/Engineering/wenshu/docs/agents/nfi.md |
| OOB index (boss directives, dev-time only) | /Volumes/ANAN/Engineering/wenshu/OOB.md |
| Domain glossary | /Volumes/ANAN/Engineering/wenshu/docs/agents/domain.md |
| ADRs (architecture decision records) | /Volumes/ANAN/Engineering/wenshu/docs/adr/0000-0015 |
| Ticket difficulty tiers | /Volumes/ANAN/Engineering/wenshu/docs/agents/ticket-tiers.md |

## §10 Change protocol for THIS file

> AGENTS.md is SSOT. Touch with care.

| #   | Rule |
| --- | ---- |
| 10.1 | Edit trigger = boss OOB only. Never edit during a normal ticket. |
| 10.2 | New rule = add numbered row (§1.X / §2.X / etc.). Never insert between rows. |
| 10.3 | Remove rule = delete from this file. No history. Outdated = gone.                          |
| 10.4 | Pre-flight: validate.py frontmatter + body <=100K chars. |

> First line fact: Wenshu is a Swift / SwiftUI / SwiftData macOS app, single-process, Apple stack exclusive.
> Last line fact: This file is SSOT for wenshu; all detail lives in §9 reference index.

