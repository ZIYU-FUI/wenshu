# SPEC-v0.01.0.md · Wenshu 7-zone layout shell

> Spec for v0.01.0: 7-zone layout shell (= FCP-inspired, functional naming, Apple HIG)
> Built on CONTEXT.md §1-§8 (= 11 owner decisions + 5-zone new meaning + workflow + tech stack)
> Source-of-truth: @wenshu-pour/architecture/CONTEXT.md (= owner 11 decisions, 2026-08-14 grill-me)
> Owner direct: "A, 参考 FCP 做, 各区按功能能力命名 (= 不上下左右)"

## Problem Statement

Wenshu v0.00.0 is a minimal SwiftUI app with one window titled "文枢" and one placeholder `ContentView` (= commit `40153410c`). It has no 5-zone layout, no functional capability, no panel hierarchy. The owner has 11 decisions documented in `CONTEXT.md` (§1-§8) specifying:
- 5 large zones that don't change (= owner Q4)
- `topLeft` (= Binder) split into 2 sub-zones + `bottomRight` (= Console/Status) split into 2 sub-zones (= owner Q5, "7 panes" decision reset to old-origin/main)
- Functional naming (= owner 18:00: "各区命名别用上下左右, 按功能大区能力命名")
- FCP-inspired visual grammar (= owner 18:00: "参考 FCP 做")

Without a layout shell, no other ticket (= Wenshu assistant / smart context picker / chat / etc.) can be implemented or visually verified.

## Solution

Build a single SwiftUI view tree that renders 7 functional zones in FCP's layout grammar:
- **Toolbar** (top, 8 buttons) — cross-zone operations (= + / import / 显隐开关 ×4 / share)
- **Library** (top-left, 4 tabs) — content source (= project / chapter / setting / material)
- **Editor** (top-center, 1 tab) — Scrivener/Obsidian editor, read-write unified (= AI draft + formal docs)
- **Inspector** (top-right, 3 tabs) — attribute inspector (= show / inspect / foreshadow)
- **Chat** (bottom-left, 4 tabs) — Wenshu assistant + implicit editorial (= summary / character / collector / TODO)
- **Console** (bottom-right-A, 1 block) — live stats / research progress / background TODO
- **Status** (bottom-right-B, 1 block) — stage gate / kanban / TODO completion

Each zone renders with a **dim background watermark** showing its functional name (e.g. `LIBRARY` rendered as a 96pt translucent gray text), so the owner can visually verify zone identity at the lowest seam (= boot → screenshot → match watermark to expected name).

Visual grammar (= FCP 实机 vision_analyze 2904×1968 retina):
- Panel dividers = 1pt hairline separator (`Color.secondary.opacity(0.15)`)
- Panel headers = 28pt ICON-only tab strip (= HorizontalIconTabStrip component, 1pt selected indicator)
- Toolbar buttons = 28×28 rounded rectangle (= 6pt corner, Color.secondary fill, Color.accentColor when active)
- Different panel backgrounds = `Color(NSColor.windowBackgroundColor)` (sidebar) / `.black` (editor) / `Color(NSColor.controlBackgroundColor)` (inspector)

## User Stories

1. As an author, I want to see 7 distinct zones when I open Wenshu, so that I can visually distinguish Library / Editor / Inspector / Chat / Console / Status.
2. As an author, I want each zone to display its functional name as a background watermark, so that I can verify the zone at a glance without reading code.
3. As an author, I want Library (= top-left, 4 tabs) to show my project's content tree, so that I can navigate novels / chapters / settings.
4. As an author, I want Editor (= top-center) to open any markdown file from my project, so that I can read and write the content (= Scrivener/Obsidian-like editor, read-write unified).
5. As an author, I want Inspector (= top-right, 3 tabs) to show my project's metadata (= foreshadow / facts / consistency), so that I can audit my novel's continuity.
6. As an author, I want Chat (= bottom-left, 4 tabs) to talk to the Wenshu assistant, so that I can drive project setup + research via natural conversation.
7. As an author, I want Console (= bottom-right-A) to show background TODO + research progress, so that I can see AI后台 running tasks without disturbing chat.
8. As an author, I want Status (= bottom-right-B) to show stage gates + kanban, so that I can track idea → setting → outline → text progression.
9. As an author, I want Toolbar (= top, 8 buttons) to give me cross-zone operations (= create / import / show/hide panels / share).
10. As an author, I want all 7 zones to use Apple HIG + Apple-provided components (= HSplitView / VSplitView / SF Symbols 6 / Color.accentColor), so that Wenshu feels like a native macOS app.
11. As an author, I want the 7-zone layout to be the seam I can verify by `swift run` + screenshot, so that subsequent tickets (Wenshu assistant / smart context picker / etc.) build on a known-correct shell.
12. As an author, I want the layout to render without runtime errors (= swift build exit 0 + process alive + screenshot non-zero), so that I can verify the shell is real.

## Implementation Decisions

**Architecture: 7 functional zones via Apple-provided layout primitives only.**

- `WindowGroup("文枢")` + `NavigationStack` (Apple HIG macOS 14+)
- Top toolbar = `HStack` of 8 `Button` glyphs (28×28)
- 4-column horizontal split = `HSplitView` (= Apple SwiftUI 27.0 standard)
- 2-row vertical split (top vs bottom bands) = `VSplitView` or `HStack(spacing: 0) { top + Splitter + bottom }` (= Apple SwiftUI 27.0)
- Sub-splits inside top band (Library / Editor / Inspector) = `HSplitView`
- Sub-splits inside bottom band (Chat | Console | Status) = `HSplitView`

**7 functional zones as independent View structs (= owner accepted naming convention):**

```
struct ToolbarView: View { ... }      // 8 buttons, owner Q5 trigger + 显隐 + share
struct LibraryView: View { ... }      // 4 tabs: project / chapter / setting / material
struct EditorView: View { ... }       // 1 tab + read-write markdown
struct InspectorView: View { ... }    // 3 tabs: show / inspect / foreshadow
struct ChatView: View { ... }         // 4 tabs: summary / character / collector / TODO
struct ConsoleView: View { ... }      // 1 block: background TODO + research progress
struct StatusView: View { ... }       // 1 block: stage gates + kanban
```

Each zone View contains a `WatermarkText(name: "LIBRARY")` overlay (= `Color.secondary.opacity(0.08).font(.system(size: 96, weight: .bold))`).

**Layout tree (= 3-level HSplitView + 1 outer VSplitView):**

```
WindowGroup("文枢")
└── NavigationStack
    └── VSplitView
        ├── HSplitView { LibraryView │ EditorView │ InspectorView }
        └── HSplitView { ChatView │ VSplitView { ConsoleView │ StatusView } }
```

**Apple HIG decisions:**

- Toolbar buttons = `Image(systemName: ...)` (SF Symbols 6) + `Button(.plain)` + `.help(...)` for accessibility
- Panel dividers = Apple default `HSplitView` / `VSplitView` rendering (= 1pt hairline at 27.0 default)
- Panel headers = `HorizontalIconTabStrip` (= Apple HIG macOS tab strip)
- Panel content backgrounds = SwiftUI `Material` (`Material.regular` for sidebars, `Color.black` for editor)

**Owner verbatim quotes honored (= CONTEXT.md §1):**

- Q5: "Click book on binder → 4 zones all switch" (= Library zone = single source for switching)
- Q10: "topCenter reading = Scrivener/Obsidian-like editor, read-write unified"
- Apple HIG: "Apple-feel UI", "Don't clone Obsidian UI", "Don't clone Scrivener UI", "use Apple's provided APIs"

**NOT in this spec (= owner-accepted deferral):**

- ❌ No Wenshu assistant (= Q2/Q3/Q9 follow via /to-tickets)
- ❌ No smart context picker (= Q11 follow via /to-tickets)
- ❌ No CoreData / no LLM client (= AGENTS.md §8 owner-accepted: v0.00.0 = empty window + §8 = historical)
- ❌ No .ws / no markdown import / no YAML frontmatter indexing (= CONTEXT.md §5 owner-deferred)

## Testing Decisions

**Seam: lowest** (= owner拍 18:05 "A, 用背景暗文字标识出各区名字即可").

A good test = verifies the layout shell renders without runtime errors and shows the expected 7 zones with watermarks.

- **Build smoke test** (= local, fast): `swift build` exit 0. Done in <2s after incremental.
- **Runtime smoke test** (= local, fast): `swift run` produces an alive `WenshuApp` process within 10s. Verified via `pgrep -f WenshuApp`.
- **Visual verification** (= manual, owner does it): screenshot shows 7 zones with watermark text (= `LIBRARY`, `EDITOR`, `INSPECTOR`, `CHAT`, `CONSOLE`, `STATUS`, `TOOLBAR`). Owner reviews the screenshot and拍 yes/no/fix.

**What we don't test (= deferral):**

- ❌ Unit tests for zone logic (= no logic yet, just placeholders)
- ❌ Interactive tests (= owner reviews visually, no automated interaction)
- ❌ Cross-device iCloud sync (= CONTEXT.md §5 defer)
- ❌ Wenshu assistant agent dispatch (= CONTEXT.md §7 follow via /to-tickets)

## Out of Scope

- ❌ Wenshu assistant (= owner Q2/Q3/Q9, follow via /to-tickets)
- ❌ Smart context picker (= owner Q11, follow via /to-tickets)
- ❌ CoreData + .ws file persistence (= AGENTS.md §8 owner-deferred, v0.01.x)
- ❌ minimax cn LLM client + SSE parser (= AGENTS.md §8 owner-deferred, v0.01.x)
- ❌ Markdown renderer with YAML frontmatter indexing (= v0.02.x after Editor zone lands)
- ❌ iCloud Drive sync (= CONTEXT.md §5 owner-deferred)
- ❌ macOS Keychain LLM key storage (= CLAUDE.md §9 owner-deferred)
- ❌ Edit / create / import operations (= Toolbar buttons are placeholders; functional via /to-tickets)
- ❌ Cross-zone state sync (= Library → Editor selection sync, deferred to follow-up ticket)

## Further Notes

- **Owner verbatim language:** "A, 参考 FCP 做" (= owner 18:00 reply). "用背景暗文字标识出各区的名字即可" (= owner 18:10 seam拍).
- **Boss 17:30 + 17:50:** Comments = English. Code = English (WenshuApp, ToolbarView etc.). UI strings = Chinese ("文枢"). Owner terminology = "owner" (internal docs) vs "老板" (conversation).
- **Apple HIG strict:** No custom color literals (= `Color.accentColor` / `Material.regular` / `Color.secondary`). No custom corner radius literals (= `.continuous` ShapeStyle). No custom font sizes (= `.body` / `.title`).
- **Memory ground truth:** `wenshu-pour/architecture/CONTEXT.md` (= owner 11 decisions). This spec honors all 11 verbatim quotes.

---

*SPEC-v0.01.0 · Wenshu 7-zone layout shell · 2026-08-14 · owner-confirmed via /grill-me 11-round + /to-spec synthesis*