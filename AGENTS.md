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
| 1.7 | Nervous file index (NFI) registration: every extracted/added file (god-class split, scope views, helper namespace) MUST be registered in this section with parent ref + LOC + content tag. Discoverability < 5s by name. | Manual. |
| 1.8 | High information density. One line per argument. No narrative paragraphs. | wenshu-humanizer-voice. |
| 1.9 | Auto-load wenshu-pocock-workflow on every wenshu turn (forced via .hermes.md at repo root). | Path-enforced. |
| 1.10 | One ticket = one commit + one atomic verification + one 4-section business-language spec + one dual-axis dispatch + one P0 fix + one verify round + merge gate. | universal-pocock-workflow. |
| 1.11 | NFI (nervous file index) = this section's table. Lists every file split from a god-class or extracted to its own file via A55+ arcs. Each row: parent file, current LOC, content tag. The next reader finds the file by concern in < 5s. | Manual. |

### §1.11 Nervous file index (NFI)

| Parent (god-class) | Extracted file | LOC | Content tag |
| ------------------ | -------------- | --- | ----------- |
| `Sources/.../ImportService.swift` (now 444 LOC, under cap) | `Sources/.../ImportServiceCancellation.swift` | 129 | `extension ImportService { cancel() rollback() resetRollbackTrail() snapshotReferenceLibraryIndex() }` = the cancel + rollback surface. |
| `Sources/.../ImportService.swift` | `Sources/.../ImportServiceDedup.swift` | 118 | `enum ImportServiceDedup { findEntityByTitle + normalizeTitle + sanitizeFilename }` = dedup + filename helpers. |
| `Sources/.../ImportService.swift` | `Sources/.../ImportServiceFileSystem.swift` | 74 | `enum ImportServiceFileSystem { walkSourceDir }` = file-system walker. |
| `Sources/.../ImportService.swift` | `Sources/.../ImportServiceHashing.swift` | 89 | `enum ImportServiceHashing { sha256 + uuidFromHash }` = hash + UUID-derivation helpers. |
| `Sources/.../ImportService.swift` | `Sources/.../ImportServiceCache.swift` | 83 | `enum ImportServiceCache { dedupAndHash + readCache + writeCache }` = dedup + cache IO helpers. |
| `Sources/.../ImportService.swift` | `Sources/.../ImportServiceDispatchHelpers.swift` | 85 | `enum ImportServiceDispatchHelpers { filterRetryCandidates + selectRetryIndices }` = dispatch retry selection. |
| `Sources/.../ImportService.swift` | `Sources/.../ImportServiceTitleOnlyHelpers.swift` | 110 | `enum ImportServiceTitleOnlyHelpers { runRetryTaskGroup + 5 retry helpers }` = title-only retry pipeline. |
| `Sources/.../ImportService.swift` | `Sources/.../ImportServiceBodyWriter.swift` | 63 | `extension ImportService { writeMainFileAndExtras }` = main body writer (split into sub-helpers). |
| `Sources/.../ImportService.swift` | `Sources/.../ImportServiceExtraFileWriter.swift` | 97 | `extension ImportService { writeExtraFile }` = extra file writer. |
| `Sources/.../ImportService.swift` | `Sources/.../ImportServiceReferenceWriter.swift` | 70 | `extension ImportService { writeReference }` = reference file writer. |
| `Sources/.../ImportService.swift` | `Sources/.../ImportServiceWriters.swift` | 271 | `extension ImportService { writeFile + writeToBookFolder + writeToReferenceLibrary }` = 3 file-write helpers. |
| `Sources/.../WenshuAppDelegate.swift` (471 LOC, under cap) | `Sources/.../WenshuAppDelegateSwiftDataMigration.swift` | 186 | `enum WenshuAppDelegateSwiftDataMigration { attemptSwiftDataMigrationIfNeeded + runSwiftDataMigrationPipeline + writeMigrationBackup + bumpSchemaVersion }` = the SwiftData migration surface. |
| `Sources/.../ImportDocumentTemplates.swift` (under cap) | `Sources/.../WorldSubSection.swift` | 172 | `enum WorldSubSection { 6 cases }` = the 6-case world sub-section enum. |
| `Sources/.../ImportDocumentTemplates.swift` | `Sources/.../ImportDocumentTemplateSkeletons.swift` | ~428 | `static let` 6 per-template skeleton constants. |
| `Sources/.../WenshuConductorImportRouter.swift` (under cap) | `Sources/.../WenshuConductorImportRouterHelpers.swift` | ~709 | `enum WCIRHelpers { 18 static helpers }` = routing orchestrator helper namespace. |
| `Sources/.../Library/Service/SidebarService.swift` (under cap) | `Sources/.../Library/View/SidebarServiceMutation.swift` | ~577 | `enum SidebarServiceMutation { 18 static helpers }` = sidebar mutation namespace. |
| `Sources/.../Editor/View/PreviewPane.swift` (now 768 LOC, 1.28x cap, remains 1 main view) | `Sources/.../Editor/View/PreviewPaneCard.swift` | 443 | `internal struct Card: View` + `internal enum CardSource` = the card UI sub-view. |
| `Sources/.../Editor/View/PreviewPane.swift` | `Sources/.../Editor/View/PreviewPaneModels.swift` | ~284 | 5 supporting types for the preview pane. |
| `Sources/.../Editor/View/PreviewPane.swift` | `Sources/.../Editor/View/PreviewPaneScopeViews.swift` | 149 | `extension PreviewPane { referenceScopeView + bookScopeView + shelfScopeView + emptyScopeView }` = 4 scope views. |
| `Sources/.../Editor/View/PreviewPane.swift` | `Sources/.../Editor/View/PreviewPaneDataAccess.swift` | 76 | `extension PreviewPane { ensureCardService + loadBooksInShelf + loadShelfBooksAsync }` = data accessors. |
| `Sources/.../Editor/View/PreviewPane.swift` | `Sources/.../Editor/View/PreviewPaneGrids.swift` | 351 | `extension PreviewPane { 6 grid view helpers }` = referenceCategoryCard + emptyState + emptyScopeView + categoryGrid + categoryGridContent + overviewGrid + bookDocsGrid. |
| `Sources/.../Chat/View/ChatView.swift` (now 1360 LOC, 2.27x cap, remains 1 main view) | `Sources/.../Chat/View/ChatViewMarkdownIO.swift` | 91 | `enum ChatViewMarkdownIO { markdownForConversation + importMarkdown }` = chat markdown IO namespace. |
| `Sources/.../Chat/View/ChatView.swift` | `Sources/.../Chat/View/ChatTurn.swift` | 40 | `struct ChatTurn: Identifiable` = the transcript grouping type. |
| `Sources/.../Agent/Service/BookChapterTool.swift` (now 1045 LOC, 1.74x cap) | `Sources/.../Agent/Service/BookChapterFileSystem.swift` | 150 | `extension BookChapterActor { saveFileSystemChapter + writeFileSystemChapter + deleteFileSystemChapter + ensureChaptersDirectoryExists + atomicWrite }` = 5 file-system static helpers. |
| `Sources/.../App/WenshuAppMain.swift` (= the @main App struct, formerly `App.swift` at root) | `Sources/.../App/AppNotifications.swift` | 171 | `enum AppCommands + enum AppStateEvents + enum LayoutEvents` = 3 cross-cutting NotificationCenter naming enums. |
| `Sources/.../Features/Shared/Backup.swift` (formerly at `Features/Shared/`) | `Sources/.../Features/Backup/Service/Backup.swift` | 219 | `struct BackupMetadata + struct BackupTools + enum BackupError` = 3 backup types (= 5 callers in LibraryMigrator + SubAgentRunner + CuratorBackup + ArchivistStorage + WenshuAppDelegateSwiftDataMigration). |
| `Sources/.../Features/Shared/AppBackupOps.swift` (formerly at `Features/Shared/`) | `Sources/.../Features/Backup/Service/AppBackupOps.swift` | 95 | `enum AppBackupOps` = @MainActor App-side wrapper for BackupTools. |
| `Sources/.../App/WenshuAppMain.swift` (the @main App shell) | `Sources/.../Features/Chrome/View/ChromeMainToolbar.swift` | 148 | `struct ChromeMainToolbar: ToolbarContent` = the 11 independent-window button row (= 1 source of truth for the title bar). |
| `Sources/.../Features/Chrome/View/ChromeMainToolbar.swift` | `Sources/.../Features/Chrome/View/WindowOpenButton.swift` | 98 | `struct WindowOpenButton: View` = reusable button format (= Image(systemName:) + .help + openWindow). |
| `Sources/.../LibraryRootView.swift` (804 LOC, 1.34x cap, the 4 sibling dirs are at the 4 features) | `Sources/.../Library/View/AppleSidebarView.swift` | 993 | god-class TODO (split candidate for A150+). |

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
| 6.8 | Root-level tree: 8 visible dirs + dot-dirs + top-level files = canonical. Sources/ + Tests/ + Scripts/ + Tools/ + build/ + docs/ + research/ + pocock/. Each has ONE purpose. Hidden dirs (.git / .git-hooks / .github / .hermes / .archive / .build / .claude / .hilo / .repowise / .scratch / .swiftpm / .test-backup-x-N/) either git-tracked (rule-defined) or .gitignore'd (no manual drift). | boss OOB 2026-10-16. |
| 6.9 | Single-purpose rule. Any dir containing exactly 1 file with 0 dependents = deletion candidate (= per-ticket spec lives in .scratch/; = research lives in research/<topic>/ per .scratch/ rule; = ticket-era docs go in Scripts/ + docs/adr/ + docs/agents/). No single-file dirs at root level. | boss OOB 2026-10-16. |
| 6.10 | Top-level purpose map. Sources/ = Swift app (canonical). Tests/ = Swift test target (= SwiftPM mirror of Sources/). Scripts/ = shell + python helpers + screenshot scripts (§7.7 visual proof gate). Tools/ = devtool + double-axis sweep (= §7.4). build/ = swift build output (.gitignored). docs/ = SSOT docs (= adr/ = decisions; = agents/ = per-role). research/ = per-topic Apple API investigations (= same shape as .scratch/; = one doc per .scratch/<date>-<topic>/ arc). All persistence/DX helpers in Scripts/. | boss OOB 2026-10-16. |

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
| 8.2 | Code + smoke test + reproduce. | diagnosing-bugs. |
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
| OOB index (boss directives, dev-time only) | /Volumes/ANAN/Engineering/wenshu/OOB.md |
| Domain glossary | /Volumes/ANAN/Engineering/wenshu/docs/agents/domain.md |
| ADRs (architecture decision records) | /Volumes/ANAN/Engineering/wenshu/docs/adr/0000-0015 |

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

