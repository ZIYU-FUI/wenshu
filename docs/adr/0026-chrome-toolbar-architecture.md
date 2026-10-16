# ADR-0026: Chrome Toolbar + Window Architecture Arc (A91-A97)

## Status

Accepted. This ADR documents the chrome toolbar (= Features/Chrome/)
extraction arc that resolved 3 layered OOB violations and the
`/Features/Shared/` directory scattering.

## Context

Per AGENTS.md §6.2 (4-slot per feature) + §6.5 (file naming)
+ the boss 2026-10-16 OOB sequence, the project had 3
structural issues that the A91-A97 arc closed:

- The 11 independent-window buttons in `ChromeMainToolbar` were
  duplicated in `InspectorView` (= 2 sources of truth; = the
  title bar showed each window entry twice).
- The toolbar button format was a per-site `SFIcon(...)` +
  `Button { openWindow }` composite that was duplicated 3x (= in
  Chrome + Inspector + the AppDelegate bridge).
- The SFIcon factory was wrapping `Image(systemName:)` for toolbar
  buttons where Apple's canonical path (= direct
  `Image(systemName:)` + `.font(.system(size: 14))`) was both
  more direct AND matched the Apple HIG `NSToolbar` defaults.
- The `Features/Shared/` directory held 4 files that did not
  belong together (= 2 backup + 1 cross-cutting notification
  + 1 dead code), with no 4-slot subdir structure.
- The `App.swift` at the project root and `App/` subdir were
  two App-related concerns at different levels (= visual
  duplicate).
- The 3-layer `Core/Agent/Conversation/` tree held 1 design doc
  with no .swift siblings (= the wrapper was vestigial).
- The `UI/` directory at project root held 2 markdown docs
  (= ComponentIndex + SFRegions) that described Shared/UI
  components (= they were 1 level away from what they documented).

## Decision

A91-A97 created the canonical chrome directory + extracted
the toolbar format + consolidated the duplicate windows
+ deleted the orphan `Core/` tree.

## A91 = Create Features/Chrome/ + relax §6.2/§6.5

Per boss 2026-10-16 OOB "标题栏/工具栏应该拆出来一个独立目录
来处理" (= the title bar / toolbar should be split out
into a dedicated directory): created `Features/Chrome/View/`.

- Moved 2 chrome components from `Shared/UI/` (= `ChromeTopBar`
  + `ChromeBottomFooter`) into `Features/Chrome/View/`.
- Relaxed AGENTS.md §6.2 from the 5-slot Apple Backyard Birds
  shape (`Views/ / ViewModels/ / UseCases/ / Repositories/ /
  Models/`) to the project's actual 4-slot shape
  (`Views/ / Model/ / Service/ / Store/`). Boss chose option 1
  (= "按需来" = use only what each feature actually needs;
  = leaf features with ≤3 files skip `Store/`).
- Relaxed AGENTS.md §6.5 file naming from the Apple suffixes
  (`View/ / ViewModel/ / UseCase/ / Repository/ / Service`) to
  the project's actual suffixes (`View/ / Ops/ / Service/
  / State`).

## A92 = Extract ChromeMainToolbar

The main toolbar (= the 11 independent-window button row) was
previously inline in `LibraryRootView.body` as 2 `.toolbar {}`
blocks. Extracted to `Features/Chrome/View/ChromeMainToolbar.swift`
(= 146 LOC; = `struct ChromeMainToolbar: ToolbarContent` with
`openWindow` + `sheetRequests` injected + 11 placeholder window
buttons).

This is the canonical full set of the 11 window buttons
(= 1 source of truth for the title bar).

## A93 = Create 11 dedicated Features for the 11 windows

Per boss 2026-10-16 OOB "用不用每一个都像截图一样拆出来"
(= each window like the screenshot): the 11 toolbar window
buttons need their own Feature directory (= 1 feature per
window). Created:

- `Features/Attachments/View/AttachmentsWindow.swift`
- `Features/Canvas/View/CanvasWindow.swift`
- `Features/Composer/View/ComposerWindow.swift`
- `Features/Cron/View/CronWindow.swift`
- `Features/Foreshadowing/View/ForeshadowingGraphWindow.swift`
- `Features/Kanban/View/KanbanWindow.swift` (pre-existing)
- `Features/LibraryMigration/View/LibraryMigrationPanel.swift`
- `Features/Manifest/View/ManifestWindow.swift`
- `Features/MemoryHistory/View/MemoryHistoryView.swift`
- `Features/Summaries/View/SummariesWindow.swift`
- `Features/Todo/View/TodoWindow.swift`

Result: the project tree no longer has a phantom App-
target subdir; = each window has a discoverable 1-step
path (= 11 features × 1 file each + the future feature
content = the §6.2 4-slot will fill in over time).

## A94 = WindowOpenButton (1 source of truth for button format)

Per boss 2026-10-16 OOB "如果涉及到格式的，写在一个文件里才
好控制格式" (= if the format is involved, write in 1 file
to control the format): the 3 `SFIcon + label + help +
openWindow` composites were consolidated into
`Features/Chrome/View/WindowOpenButton.swift` (= 98 LOC;
= `struct WindowOpenButton: View` with `id / icon / title /
style / openWindow / isEnabled` parameters).

ChromeMainToolbar uses `WindowOpenButton` for all 11 buttons
(= 1 source of truth = changing the icon style / tooltip
pattern now happens in 1 place).

## A95 = Drop the disabled placeholder concept

Per boss 2026-10-16 OOB "不是未开发，是没开发完，之前是有面
板的" (= not undeveloped, was unfinished, panels existed
before): the previous A92 marked 8 of 11 windows as
`isEnabled: false` (= they showed as greyed-out). Boss
corrected: all 11 windows have actual panels (= 5 callers
in `LibraryMigrator + SubAgentRunner + CuratorBackup +
ArchivistStorage + WenshuAppDelegateSwiftDataMigration` +
the 11 A93 directories).

Renamed `PlaceholderButton` → `ToolbarButton`, removed the
`isEnabled: Bool` field from `WindowOpenButton` (= default
`true` for all 11 = 0 greyed-out buttons).

## A96 = Use `Image(systemName:)` directly (drop SFIcon wrapper for toolbar)

Per boss 2026-10-16 OOB "SF 符号，apple 没有库引入吗，我怎
么感觉我们现在没有直接用，而是绕远了一下" (= SF Symbols,
Apple has the library, we use it directly without
indirection): the previous A94 used `SFIcon(icon, style: .small)`
which is the project's design-system factory for list /
sidebar / table icons (= enforces size / weight / color /
rendering mode consistency). For toolbar buttons specifically:

- The icon style is pinned by the toolbar's `ControlSize` +
  Apple's `NSToolbar` defaults (= 14 PT .regular per Apple HIG).
- All 11 call sites used the same `.small` style (= the
  `style:` parameter was dead flexibility).
- Direct `Image(systemName:)` is the Apple-canonical SF
  Symbols 6 path (= SwiftUI's built-in renderer; = no import
  needed, no library).

WindowOpenButton now uses
`Image(systemName: icon).font(.system(size: 14, weight: .regular))
.foregroundStyle(.secondary)` directly (= Apple HIG 1:1).

The SFIcon factory itself is unchanged (= still serves list
/ sidebar / table / pane contexts where 6 decision points
need enforcement per the v3.0 design system hard rule).

## A101-A106 = Directory hygiene (= the 3-layer / shared / duplicate cleanup)

- A101: Collapsed 3-layer `Core/Agent/Conversation/` tree
  that held only 1 design doc (= `AgentLifecycleTrackerDesign.md`
  = 6 KB) → moved to `Features/Agent/Store/AgentLifecycleTracker
  Design.md` next to the implementation it describes. Removed
  the empty `Core/Agent/Conversation/` + `Core/Agent/` + `Core/`
  directory.
- A102: Created `Features/Backup/Service/` (= sibling of
  `BookChapterTool` / `WenshuVerifier` etc.). Moved 2 backup
  files from `Features/Shared/` (= `Backup.swift` =
  `BackupMetadata + BackupTools + BackupError`) + (`AppBackupOps.swift`
  = `@MainActor` App-side wrapper).
- A103: Moved `AppNotifications.swift` (= 3 enums for
  `NotificationCenter` naming) from `Features/Shared/` to
  `App/` (= alongside `AppRootScene` + `WenshuAppDelegate`
  + `WenshuAppDelegateLLM` + `WenshuAppDelegateSwiftDataMigration`).
- A104: Deleted dead `BaseParser.swift` (= 88 LOC; 0 callers
  anywhere in the project) + the orphan `Features/Shared/`
  directory.
- A105: Moved `App.swift` (= the `@main struct WenshuApp: App`
  at project root) to `App/WenshuAppMain.swift`. Renamed for
  clarity (= the file is the project's @main entry; = matches
  the §6.5 file-naming rule for App-target concerns).
- A106: Moved `UI/ComponentIndex.md` + `UI/SFRegions.md` to
  `Shared/UI/ComponentDocs/` (= the docs describe the
  `Shared/UI/` components; = 1 step closer to what they
  document).

## Result

`Sources/WenshuApp/` is now structurally clean:

- `App/` (= 1 dir for all App-target concerns, 6 files)
- `Features/` (= 20+ feature dirs, 11 of which were created
  in this arc = 1 per window)
- `Resources/` (= static assets + localization)
- `Shared/` (= 1 dir for cross-cutting utilities, 3 subdirs:
  Foundation/ + State/ + UI/)
- `DesignTokens.swift` (= design tokens global dict)

= 5 categories, mutually exclusive, collectively exhaustive
(= 老板 2026-10-16 5 类互斥原则).

## NFI updates

§1.11 Nervous file index added 12 new rows in A107
documenting the chrome toolbar / window / shared / core
extractions.

## Build / test verification

- 13 commits (A91-A97, A101-A106, A107, A120-A121) = 14 commits
  total in this arc.
- Build pass on all commits.
- 401 WenshuApp tests pass + 3 WenshuData test suites
  pre-existing failures unchanged (= ADR-0023 documented).
- Project tree is now discoverable: any feature is 1
  `cd Sources/WenshuApp/Features/<feature>/` away.
