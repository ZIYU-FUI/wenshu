# Spec — WenshuCore replica modules front-end integration requirements list (老板 2026-08-19 evening 拍)

> Date: 2026-08-19
> 老板 2026-08-19 evening 拍 "these modules need front-end calls, we haven't integrated them into the front end yet, can you organize a requirements list, listing the replica-required functions to integrate into the front end"
> Truth source: wenshu repo Sources/WenshuApp/Core/ (14 truth modules, 老板 8/19 + cc-runner 22:27+ ran) + Sources/WenshuApp/Views/ (Layout + Library already exist)

## Problem Statement

老板 2026-08-19 evening 拍: wenshu backend (Sources/WenshuApp/Core/) has 14 truth modules (Memory / Skill / Agent / Kanban / Todo / Tools / Cron / Backup / MiniMax verification + cc-runner added Canvas/LinkGraph/Outline/Search/Templates/WordCount) but **the front end hasn't integrated them**. Need to organize a requirements list.

Business-language description (老板 understands):
- Backend done, front end not connected
- 老板 needs 1 requirements list = which modules connect front end + how to connect + workload
- wenshu positioning = SwiftUI desktop writing app (same as Pages / Scrivener)
- Front-end integration per Apple HIG truth (Apple native UI, SwiftUI)

## Current state (Q22 truth-verified)

Backend truth modules (Sources/WenshuApp/Core/, 14 truth):
- Memory (MemoryStore.swift) — local SQLite long-term memory
- Skill (SkillRegistry.swift) — local SKILL.md loading
- Agent (AgentProtocol.swift + AgentRuntime.swift + MiniMaxVerifier.swift) — A2A protocol + multi-agent + MiniMax verification
- Kanban (KanbanStore.swift) — local Kanban + 7 statuses
- Todo (TodoStore.swift) — local Todo + 4 statuses + 4 priorities
- Tools (FileTools / ProcessTools / WebTools / VisionTools / AVMediaTools) — 5 tools
- Cron (Cronjob.swift) — local cron tasks
- Backup (Backup.swift) — local project backup
- cc-runner 22:27+ added backend: Canvas / LinkGraph / Outline / Search / Templates / WordCount

Front-end current state (Sources/WenshuApp/Views/):
- Layout/ — LayoutShellView (6-zone layout)
- Library/ — LibraryOutlineView (project sidebar real content)

Unintegrated front-end modules = **all 14 truth modules** (excluding Layout / Library already there)

## Requirements list (by wenshu positioning + workload + priority)

| # | Requirement | Module | Integration approach (Apple HIG) | Workload | Priority | Verification |
|---|---|---|---|---|---|---|
| 01 | **Memory UI** | MemoryStore | SwiftUI `.onAppear` inject, Toolbar "Memory" button + Popover shows add / search list | Medium | 🔥 High | 老板 can query "what has wenshu written" |
| 02 | **Skill UI** | SkillRegistry | Settings menu (cmd+,) add "Skills" list, show loaded skills + invoke input | Medium | 🔥 High | 老板 can manually invoke skill |
| 03 | **MiniMax Agent UI** | AgentProtocol + MiniMaxVerifier | Toolbar add "Agent" button, pop chat sheet (user sends message → agent replies) | Large | 🔥 High | 老板 can chat directly with MiniMax |
| 04 | **Kanban UI** | KanbanStore | Sidebar add "Projects" tab, show wenshu project kanban (backlog / in-progress / done) | Medium | 🟡 Medium | 老板 sees wenshu's own project progress |
| 05 | **Todo UI** | TodoStore | Sidebar add "Today" tab, show due / priority todos, simple GTD | Medium | 🟡 Medium | 老板 has wenshu internal todos |
| 06 | **File Tools UI** | FileTools | Editor right-click menu + Toolbar "Open/Save" buttons (Apple NSOpenPanel + NSSavePanel) | Small | 🟡 Medium | 老板 imports/exports text within wenshu |
| 07 | **Process UI** | ProcessTools | Toolbar add "Run" button, pop NSTextField input shell command, output in sheet | Medium | 🟢 Low | 老板 runs scripts within wenshu |
| 08 | **Web Fetch UI** | WebTools | Editor right-click "Insert URL" → fetch + extract + insert markdown | Medium | 🟡 Medium | 老板 grabs web content into wenshu |
| 09 | **Vision UI** | VisionTools | Editor right-click "OCR image" → recognizeText → insert text | Medium | 🟡 Medium | 老板 OCRs screenshot insert text |
| 10 | **TTS UI** | AVMediaTools | Toolbar add "Read" button → speak selected text (AVSpeechSynthesizer) | Small | 🟢 Low | 老板 can listen to wenshu reading aloud |
| 11 | **Cron UI** | Cronjob | Settings menu add "Scheduled tasks" list, show cron tasks + start/stop | Medium | 🟢 Low | 老板 can set scheduled tasks |
| 12 | **Backup UI** | Backup | Toolbar add "Backup" button → pop sheet show backup list + restore | Medium | 🟢 Low | 老板 can back up wenshu projects |
| 13 | **Multi-Agent UI** | AgentRuntime | Settings "Agents" tab, show registered agents + delegate button | Large | 🟡 Medium | 老板 can manually dispatch tasks to agents |
| 14 | **Canvas UI** | Canvas backend | Toolbar add "Canvas" button → pop JSON Canvas view (Obsidian-compatible) | Large | 🟡 Medium | 老板 can draw mind maps |
| 15 | **LinkGraph UI** | LinkGraph backend | Editor `[[wikilink]]` auto-complete + Backlinks panel | Medium | 🟡 Medium | 老板 wiki-link interconnect |
| 16 | **Outline UI** | Outline backend | Sidebar add "Outline" tab, show document heading tree (click to jump) | Small | 🟡 Medium | 老板 sees chapter structure |
| 17 | **Search UI** | Search backend | Toolbar "Search" button (cmd+shift+f) → pop full-text search sheet | Medium | 🟡 Medium | 老板 full-text search |
| 18 | **Templates UI** | Templates backend | "New" button → template selection sheet (blank / chapter / short story / note) | Medium | 🟢 Low | 老板 uses templates to open new projects |
| 19 | **Word Count UI** | WordCount backend | Status bar add word count / paragraph count (selection region) | Small | 🔥 High | 老板 sees real-time word count |

## Priority decisions

By "wenshu writing app core requirements" + 老板 8/19 evening truth-verified MiniMax:
- 🔥 **High (3)**: Memory + Skill + MiniMax Agent + Word Count
- 🟡 **Medium (8)**: Kanban + Todo + File Tools + Web Fetch + Vision + Multi-Agent + Canvas + LinkGraph + Outline + Search
- 🟢 **Low (5)**: Process + TTS + Cron + Backup + Templates

## Integration approach truth (Apple HIG)

By 4 principles + 1 pseudo-Apple-official:
- Toolbar: SwiftUI `.toolbar { Button { } }` (Apple HIG truth)
- Sheet: SwiftUI `.sheet { }` (Apple HIG truth)
- Settings: SwiftUI `Settings { }` (Apple official truth, already used in commit `4c42fa79`)
- Sidebar: SwiftUI `NavigationSplitView` or `HSplitView` (Apple HIG truth)
- Status bar: SwiftUI `.safeAreaInset(edge: .bottom)` (Apple truth)
- File selection: `NSOpenPanel` / `NSSavePanel` (AppKit truth)
- Shortcuts: `.keyboardShortcut("k", modifiers: .command)` (Apple HIG truth)

## Business-language description (老板 understands)

- 14 modules front-end integration = 19 UI requirements (including 6 backend added by cc-runner)
- Prioritize by "wenshu writing app core" (3 high / 8 medium / 5 low)
- Use Apple HIG truth (SwiftUI + AppKit, no third-party SDK)
- Engineering management authorized by 老板 (老板 8/19 拍 "you decide yourself") + no verification needed

## Implementation Decisions

Per po main flow, 19 tickets serial:
- Each ticket 1 commit + push (老板 8/19 engineering management authorization)
- Each ticket runs the full po main flow 6 steps (grill + spec + ticket + impl + code-review + domain-modeling)
- High-priority 3 tickets first (Memory + Skill + MiniMax Agent + Word Count)
- Skip requirements not belonging to wenshu writing app (e.g. smart home, messaging, browser automation)
- Do not touch hermes (read-only)
- Do not break macOS chrome 52 PT / LayoutTokens / bandH / splitters (cursor / hover / drag / 1 PT / color / rounded caps)

## Business-language description (老板 understands)

- wenshu 14 modules front-end integration = 19 UI requirements (3 high / 8 medium / 5 low)
- Prioritize by "wenshu writing app core"
- Apple HIG truth (SwiftUI + AppKit, no third-party SDK)
- Engineering management authorized by 老板 (8/19 evening 拍 "you decide yourself") + no verification needed

## Out of Scope

- Do not touch hermes
- Do not implement AppleHome / AppleMessages / Mail / Contacts / Calendar / Reminders / Notes / Photos (wenshu writing app does not integrate)
- Do not replicate all hermes capabilities (previously decided to skip 9)
- Do not rewrite WenshuApp SwiftUI UI overall architecture (incrementally add toolbar / sheet / settings)
- Do not implement front-end UI for 35 po god skills (replica core is enough)

## Further Information

- Existing front end: Sources/WenshuApp/Views/Layout/ (LayoutShellView) + Library/ (LibraryOutlineView)
- Existing settings: Settings scene (commit `4c42fa79`) — extend add Memory / Skill / Agent / Cron / Backup / Kanban tabs
- Existing Toolbar: top/bottom 30 PT (LayoutTokens.toolbarHeight) — incrementally add buttons
- Existing Notifications: NotificationCenter.default (command menu "Restore default layout" uses) — extend add cross-module notifications

## Truth references (Apple HIG)

- Toolbar: https://developer.apple.com/documentation/swiftui/view/toolbar
- Sheet: https://developer.apple.com/documentation/swiftui/view/sheet
- Settings scene: https://developer.apple.com/documentation/swiftui/scene/settings
- NavigationSplitView: https://developer.apple.com/documentation/swiftui/navigationsplitview
- safeAreaInset: https://developer.apple.com/documentation/swiftui/view/safeareainset(edge:alignment:spacing:content:)
- keyboardShortcut: https://developer.apple.com/documentation/swiftui/view/keyboardshortcut(_:modifiers:localization:)
- NSOpenPanel: https://developer.apple.com/documentation/appkit/nsopenpanel
- NSSavePanel: https://developer.apple.com/documentation/appkit/nssavepanel
- AVSpeechSynthesizer: https://developer.apple.com/documentation/avfaudio/avspeechsynthesizer

## Next step 老板 拍

Per po main flow serial 19 tickets, each ticket 1 commit + push:
1. Run all 19 tickets (5+ weeks workload, batched)
2. By "wenshu writing app core" priority (3 high first)
3. 老板 can interrupt at any time to 拍 new direction

## Task list summary (1 table for 老板 to view)

```
🔥 High (3):
  01 Memory UI     — 老板 can query "what has wenshu written"
  02 Skill UI      — 老板 can manually invoke skill
  03 MiniMax Agent UI — 老板 can chat directly with MiniMax
  19 Word Count UI — 老板 sees real-time word count

🟡 Medium (8):
  04 Kanban UI     — 老板 sees wenshu's own project progress
  05 Todo UI       — 老板 has wenshu internal todos
  06 File Tools UI — 老板 imports/exports text
  08 Web Fetch UI  — 老板 grabs web content into wenshu
  09 Vision UI     — 老板 OCRs screenshot insert text
  13 Multi-Agent UI — 老板 manually dispatches tasks
  14 Canvas UI     — 老板 draws mind maps
  15 LinkGraph UI  — 老板 wiki-link
  16 Outline UI    — 老板 sees chapter structure
  17 Search UI     — 老板 full-text search

🟢 Low (5):
  07 Process UI    — 老板 runs scripts
  10 TTS UI        — 老板 listens to wenshu reading aloud
  11 Cron UI       — 老板 sets scheduled tasks
  12 Backup UI     — 老板 backs up wenshu projects
  18 Templates UI  — 老板 uses templates to open new projects
```

## Do not touch hermes (老板 8/11 拍)

- read-only explore code
- do not modify any file under `/Volumes/ANAN/.hermes/`
- do not patch any `.py` under `/Volumes/ANAN/.hermes/hermes_cli/`