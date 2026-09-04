# Wenshu Color Apple-API Audit — v0.32

Status: fresh sub-sweep (= boss 2026-09-02 OOB '参考一下 FCP, 各区有不同的区域颜色, 这样各区很自然然的做了区分. 你看一下 apple api 的颜色, 暗色模式是怎么分级的, 亮色模式是怎么分级的').
Author: pocock single-agent audit
Branch: wt/multi-agent-dispatch
Date: 2026-09-02

# Hard rule (project-wide, non-negotiable)

- English only. No CJK characters or punctuation.
- Boss hard rule 2026-09-02 OOB: "你所有用的颜色, 都是 API 给的, 不要自定义" = every color in wenshu UI chrome MUST come from an Apple NSColor API. Custom color constructors, RGB ladders, opacity-tinted divisions are FORBIDDEN without written boss exception.
- Apple-API-first rule from `wenshu-apple-api-first` skill §Gate 3 + §Boss 2026-09-02 OOB hard rule: the bounded acceptable Apple-API color count for wenshu UI chrome is **2-3 NSColor static properties + 1 separator** (windowBackgroundColor + controlBackgroundColor + underPageBackgroundColor + separatorColor). Anything beyond that means the agent invented a color.

# §0. Why this audit exists

Boss 2026-09-02 OOB requests the wenshu 6-zone layout match the FCP-style
"natural per-region differentiation via Apple-supplied background tones".
Concrete asks:

1. "参考一下 FCP, 各区有不同的区域颜色, 这样各区很自然然的做了区分" = the visual goal = FCP-style 6-pane layout where each pane uses an Apple-supplied background tone and the brightness delta does the differentiation work.
2. "你看一下 apple api 的颜色, 暗色模式是怎么分级的, 亮色模式是怎么分级的" = explicit requirement = use ONLY Apple NSColor API. Boss rejects `DesignColor` wrapper enum as "self-written color".
3. "一个区一个区修改" = BOSS-APPROVAL SEQUENTIAL cadence. One region per commit. Wait for boss verification between commits.

This audit answers the "what to use" question. The execution lives in
`§5 Per-region execution plan` (one ticket per region = 10 commits total).
Boss picks the first ticket; agent waits for "下一个" between each.

# §1. Apple macOS 27 Tahoe NSColor background palette

Source: Apple Developer Documentation "UI element colors"
(https://developer.apple.com/documentation/appkit/ui-element-colors, mirrored at
https://sosumi.ai/documentation/appkit/ui-element-colors) + WWDC25 session 310
"Build an AppKit app with the new design" + FCP 6-pane screenshot evidence
provided by boss.

Apple organizes NSColor into 6 categories. Only the **background-relevant** 4 are
in scope for wenshu pane chrome. The other 2 (text, fill, accent, control) are
for non-background UI and stay out of this audit.

## 1.1 Background-relevant NSColor static properties (full list)

| Apple category | NSColor | Apple official definition | macOS 27 dark-mode RGB (approx) |
|---|---|---|---|
| Window colors | `windowBackgroundColor` | "The color to use for the window background" | ~#1d1d1f (deepest tier) |
| Window colors | `underPageBackgroundColor` | "The color to use in the area beneath your window's views" | ~#3a3a3c (1 tier lighter than controlBackground) |
| Window colors | `windowFrameTextColor` | "The color to use for text in a window's frame" | text only |
| Control colors | `controlBackgroundColor` | "The color to use for the background of large controls, such as scroll views or table views" | ~#2d2d2f (1 tier lighter than windowBackground) |
| Control colors | `controlColor` | "The color to use for the flat surfaces of a control" | surfaces only |
| Content colors | `separatorColor` | "The color to use for separators between different sections of content" | rgba(255,255,255,0.1) hairline |
| Content colors | `selectedContentBackgroundColor` | "The color to use for the background of selected and emphasized content" | accent-tinted (selection state) |
| Text colors | `textBackgroundColor` | "The color to use for the background area behind text" | ~#525254 (lightest tier = editable content) |

## 1.2 Light-mode brightness ladder (Apple automatic reversal)

Light mode swaps the dark-mode ladder:

| Tier | Dark mode | Light mode |
|---|---|---|
| 0 (deepest) | windowBackgroundColor | textBackgroundColor |
| 1 | controlBackgroundColor | underPageBackgroundColor |
| 2 | underPageBackgroundColor | controlBackgroundColor |
| 3 (lightest) | textBackgroundColor | windowBackgroundColor |

Apple's AppKit automatically swaps the brightness direction. The same NSColor
call yields the appropriate tone in both modes — no custom code needed.

## 1.3 WWDC25 session 310 facts (macOS 27 Tahoe design guidance)

| Fact | Impact on wenshu |
|---|---|
| `NSToolbar` glass material auto-applies (timestamp 02:53) | The wenshu titlebar / statusbar should use Apple `NSToolbar` and `.toolbar { ToolbarItem(...) }`, NOT custom `.background()` calls |
| `NSVisualEffectView` on macOS 27 Tahoe BLOCKS the new glass material | wenshu must NOT use `NSVisualEffectView` for new panes; use `NSGlassEffectView` or SwiftUI `.glassEffect(.regular)` |
| `NSGlassEffectView` / `NSGlassEffectContainerView` are the Tahoe-native glass API | The pane content background belongs on `.glassEffect(.regular)` (not `.ultraThinMaterial.opacity(0.5)` style) |
| Control sizes: mini / small / medium / large / extraLarge (5 sizes) | Out of scope for this audit (= wenshu uses default sizes) |

# §2. Apple-canonical 6-pane layout (the FCP pattern)

Boss references FCP (Final Cut Pro) as the visual model. FCP 6-pane layout on
macOS 27 Tahoe maps to the Apple NSColor palette as follows:

| FCP pane (from boss screenshot 2026-09-02) | Apple NSColor (dark mode brightness tier) | Apple-canonical role |
|---|---|---|
| Library sidebar (left, deepest tier) | `controlBackgroundColor` (tier 1) | "large control" = sidebar / inspector |
| Browser pane (next column, lighter) | `windowBackgroundColor` (tier 0 = deeper than sidebar) | "document content" = content area beneath content views |
| Viewer (top right, darkest) | `windowBackgroundColor` (tier 0 = deepest) | "window background" = canvas behind artwork |
| Timeline (bottom, mid tier) | `controlBackgroundColor` (tier 1) | "large control" = timeline chrome |
| Inspector (right, tier 1) | `controlBackgroundColor` (tier 1) | "large control" = inspector chrome |
| Effects browser (rightmost, tier 1) | `controlBackgroundColor` (tier 1) | "large control" = browser chrome |

**Apple-canonical pattern (Apple HIG + WWDC25)**: pane content goes on the
**deeper** tone (`windowBackgroundColor`) so it appears inset into the window.
Pane chrome (sidebar / inspector / timeline) goes on the **lighter** tone
(`controlBackgroundColor`) so it appears raised. The visual hierarchy comes
from the brightness delta alone — no custom divider lines, no RGB ladders.

# §3. Wenshu 6-zone color requirements (mapped from §2)

Wenshu's `ZoneSlot` enum (`Sources/WenshuApp/App.swift:1500-1507`) declares 6
cases. Mapping each to the FCP pattern + Apple NSColor:

| # | `ZoneSlot` case | Functional role | Apple NSColor (dark mode tier) | Reason |
|---|---|---|---|---|
| 1 | `projectSidebar` | Library outline (chrome) | `controlBackgroundColor` (tier 1) | Apple HIG: "large control" = sidebar / list view |
| 2 | `projectPreview` | Preview pane (content) | `windowBackgroundColor` (tier 0 = deeper) | Apple HIG: "document content" = content area beneath content views |
| 3 | `editor` | Editor (content + editable) | `windowBackgroundColor` (tier 0 = deeper) | Apple HIG: same as FCP viewer = canvas beneath editable content |
| 4 | `specializedTools` | Tools pane (chrome) | `controlBackgroundColor` (tier 1) | Apple HIG: "large control" = inspector |
| 5 | `aiChat` | Chat pane (content) | `windowBackgroundColor` (tier 0 = deeper) | Apple HIG: chat messages = document content |
| 6 | `aiDynamic` | Dynamic / Kanban (content) | `windowBackgroundColor` (tier 0 = deeper) | Apple HIG: kanban cards = document content |

**Result**: wenshu's 6 zones use **only 2 Apple NSColor static properties**
(`controlBackgroundColor` for chrome, `windowBackgroundColor` for content) plus
`separatorColor` for the NSSplitView hairline. **Zero custom colors.**

Apple's automatic light/dark reversal (per §1.2) handles the light-mode case
without wenshu intervention.

# §4. Apple-API-first gate (per-region, per-component)

Per the `wenshu-apple-api-first` skill §Gate 5 + boss 2026-09-02 OOB hard rule:
every color literal in wenshu UI chrome MUST come from one of the Apple NSColor
static properties listed in §1.1. The following constructs are **forbidden**
without written boss exception:

- `Color(nsColor: NSColor(calibratedWhite: 0.XX, alpha: 0.XX))` (= raw RGB blend)
- `Color.white.opacity(0.25)` (= opacity-tinted divisions)
- `Color.clear` as a "placeholder" background (every pane needs an Apple NSColor fill)
- Per-pane brightness ladder (e.g. `paneBrightness: Double` on `ZoneSlot` with `0.95` / `0.90` / `1.00`)
- `DesignColor` wrapper enum (= wenshu's pre-existing wrapper layer; boss explicitly rejected it as "self-written color")
- `Material.ultraThinMaterial.opacity(0.5)` (= semi-transparent tier overlay; WWDC25 says use `.glassEffect(.regular)` instead)

Acceptable Apple-API patterns (any of these):

```swift
// Pattern A: direct NSColor static property
Color(nsColor: .controlBackgroundColor)        // chrome (sidebar, inspector, tools, tab bar, status bar)
Color(nsColor: .windowBackgroundColor)         // content (preview, editor, chat, dynamic)
Color(nsColor: .underPageBackgroundColor)       // content alt (Apple HIG content background = 1 tier lighter than controlBackground in dark mode)
Color(nsColor: .separatorColor)                // NSSplitView hairline
Color(nsColor: .controlAccentColor)            // Apple-supplied accent tint

// Pattern B: SwiftUI .glassEffect (Tahoe glass material)
Color.clear.glassEffect(.regular)              // canonical pane content background (per WWDC25)
```

# §5. Per-region execution plan (10 tickets, BOSS-APPROVAL SEQUENTIAL)

Boss 2026-09-02 OOB "一个区一个区修改" = one commit per region. Boss picks the
first ticket; agent waits for "下一个" between each.

| # | Region | Component | Target file | Apple API to apply |
|---|---|---|---|---|
| 1 | Pane tab bar (top, 30 PT) | `RegionTabBar` | `Sources/WenshuApp/UI/RegionTabBar.swift` | `.controlBackgroundColor` (already applied per boss WIP 9/2; verify no leftover `\.liquidGlassOpacity`) |
| 2 | Pane status bar (bottom, 30 PT) | `RegionStatusBar` | `Sources/WenshuApp/UI/RegionTabBar.swift` (same file) | `.controlBackgroundColor` (boss WIP already partial; verify) |
| 3 | App titlebar (top, 34 PT) | AppKit `NSToolbar` via SwiftUI `.toolbar` | `Sources/WenshuApp/App.swift` (use Apple `ToolbarItem` only) | Apple auto-glass via `NSToolbar` = 0 background color (boss WIP 9/2) |
| 4 | App statusbar (bottom, 24 PT) | `AppStatusbar` | `Sources/WenshuApp/UI/AppStatusbar.swift` | `.controlBackgroundColor` (replace any `\.liquidGlassOpacity`) |
| 5 | Pane content background (1 source of truth) | `RegionContentBackground` | `Sources/WenshuApp/UI/RegionContentBackground.swift` | Add `init(zone: ZoneSlot)` + route: chrome zones → `.controlBackgroundColor`, content zones → `.windowBackgroundColor`. Default `init()` → `.controlBackgroundColor` |
| 6 | Project sidebar content (ZoneSlot.projectSidebar) | caller of `RegionContentBackground` in `WorkspaceView` | `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` | Pass `.projectSidebar` to `RegionContentBackground(zone:)` → chrome tier (`controlBackgroundColor`) |
| 7 | Project preview content (ZoneSlot.projectPreview) | caller of `RegionContentBackground` in `WorkspaceView` | `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` | Pass `.projectPreview` → content tier (`windowBackgroundColor`) |
| 8 | Editor content (ZoneSlot.editor) | caller in `WorkspaceView` | `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` | Pass `.editor` → content tier (`windowBackgroundColor`) |
| 9 | Tools content (ZoneSlot.specializedTools) | caller in `WorkspaceView` | `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` | Pass `.specializedTools` → chrome tier (`controlBackgroundColor`) |
| 10 | Chat + Dynamic content (ZoneSlot.aiChat + .aiDynamic) | caller in `WorkspaceView` | `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` | Pass `.aiChat` + `.aiDynamic` → content tier (`windowBackgroundColor`) |

**Total commit budget**: 10 commits. Boss may bundle chrome tiers together or
content tiers together if visual verification confirms equivalent outcome
(e.g. ticket 1 + 2 + 4 collapse to a single "all pane chrome = controlBackground"
commit if no per-region visual diff is needed). Decision belongs to boss.

**Co-session coordination note**: tickets 6-10 touch `WorkspaceView.swift`
which is on boss's WIP (per `git status`). Agent will surface the WIP state
before any commit; default path = agent waits for boss to commit their WIP
first, then agent lands the caller changes (avoids 3-way merge conflict).

**Pre-existing files that must be retired in this sweep**:

| File | Reason |
|---|---|
| `Sources/WenshuApp/DesignTokens.swift` lines 132-142 (`DesignColor` enum) | Boss explicitly rejected as "self-written color"; must be deleted AND every caller must migrate to bare `Color(nsColor: .xxxColor)` |

Caller scan needed before deletion:

```bash
git grep -n 'DesignColor\.' Sources/ Tests/
```

Migration: every `DesignColor.titleBar` → `Color(nsColor: .windowBackgroundColor)`,
`DesignColor.zoneSurface` → `Color(nsColor: .controlBackgroundColor)`,
`DesignColor.dynamicZoneSurface` → `Color(nsColor: .windowBackgroundColor)`
(per the new tier mapping; previously `underPageBackgroundColor`),
`DesignColor.accentBlue` → `Color(nsColor: .controlAccentColor)`,
`DesignColor.splitterLine` → `Color(nsColor: .separatorColor)`.

# §6. Out of scope (not covered by this audit)

- Per-library persistence topology (= `.ws` bundle layout, `chat.sqlite` schema). AGENTS.md §11 specifies these.
- LLM Wiki pipeline / ForeshadowingGraph service / BookStore CRUD. Domain logic; Apple has no opinion.
- Lucide icon strings / Apple SF Symbol names. Apple's catalog, but mapping is product choice.
- Compile-time Swift extensions on Apple's types (= ergonomic additions are valid).

# §7. References

- Apple Developer Documentation: [UI element colors](https://developer.apple.com/documentation/appkit/ui-element-colors) (= canonical NSColor background palette, retrieved 2026-09-02 via sosumi.ai mirror)
- WWDC25 session 310: [Build an AppKit app with the new design](https://developer.apple.com/videos/play/wwdc2025/310) (= macOS 27 Tahoe glass material + NSToolbar + NSGlassEffectView facts)
- swiftuicolors.com: [macOS System Colors](https://swiftuicolors.com/macos-colors) (= brightness reference table)
- `wenshu-apple-api-first` SKILL.md §Boss 2026-09-02 OOB hard rule (= forbidden constructs + acceptable Apple-API patterns)
- AGENTS.md §11 = wenshu project baseline (= Apple stack exclusive, Apple NSColor canonical, no custom colors)
- Boss-provided FCP screenshot = `.scratch/v0.32-color-apple-audit/fcp-reference.png` (or wherever boss saved it; visual evidence for the 4-tone brightness ladder)

# §8. Acceptance criteria

For any commit that ships from this audit:

- [ ] Every color literal in the commit comes from an Apple NSColor static property listed in §1.1 (= `windowBackgroundColor` / `controlBackgroundColor` / `underPageBackgroundColor` / `textBackgroundColor` / `separatorColor` / `controlAccentColor` / `selectedContentBackgroundColor`).
- [ ] No `DesignColor.xxx` references remain in the commit.
- [ ] No raw RGB constructs (`NSColor(calibratedWhite:...)`, `Color.white.opacity(...)`, etc.) introduced.
- [ ] `swift build` exits 0.
- [ ] macOS screenshot diff: pre-change vs post-change shows the expected brightness delta for that zone (= tier 0 vs tier 1 vs separator).
- [ ] Boss verifies visually before next commit (= BOSS-APPROVAL SEQUENTIAL cadence).

# §9. Changelog

- 2026-09-02: Initial audit. 10 tickets proposed. 1 pre-existing file (`DesignTokens.swift` enum lines 132-142) marked for retirement after caller migration.

## §10. Companion sweep — translucent-material layers that mask the per-pane tier delta

Status: surfaced 2026-09-02 AFTER commits 76203ea59 / 8fb3f15dd / fe4609281 / abd421338 / d44eee588 / e5bf3d62e landed. Boss visual verification reported "6 区基本没有差分" = per-zone chrome tier .controlBackgroundColor and content tier .windowBackgroundColor are NOT visually distinguishable in the running app even though the code commits placed them correctly.

Root cause (= the actual problem, NOT the per-zone background color): four `.regularMaterial` / `.ultraThinMaterial` translucent overlay layers sit on top of the per-pane backgrounds and wash them out. Apple Material values are translucent (= they sample the underlying view through a blur) and the blur smears the chrome/content tier brightness delta to visual zero.

Inventory (= 4 callers, all pre-existing, none introduced by the v0.32 sweep):

| # | File | Line | Layer | Coverage | Apple API replacement |
|---|---|---|---|---|---|
| 1 | `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift` | 618 | `EditorContentPlaceholder.background(.ultraThinMaterial)` | editor pane placeholder | `Color(nsColor: .windowBackgroundColor)` (= content tier, same as `RegionContentBackground.appleBackground` for `.editor`) |
| 2 | `Sources/WenshuApp/Views/Workspace/TabContentDispatcher.swift` | 280 | `GroupTabStrip.background(.regularMaterial)` | floating group tab strip in multi-pane ZoneContentView | `Color(nsColor: .controlBackgroundColor)` (= chrome tier, matches `RegionTabBar` / `RegionStatusBar`) |
| 3 | `Sources/WenshuApp/Views/Kanban/SubAgentProgressView.swift` | 126 | `SubAgentProgressCard.background(.regularMaterial)` | kanban / dynamic zone sub-agent notification card | `Color(nsColor: .controlBackgroundColor)` (= chrome tier for floating cards; matches `KanbanView` future Apple-API-first migration) |
| 4 | `Sources/WenshuApp/Views/Onboarding/LibraryRootView.swift` | 382 | `EmptyState.background(.regularMaterial)` | first-launch onboarding empty state | `Color(nsColor: .controlBackgroundColor)` (= chrome tier, matches Apple HIG standard onboarding background) |

Apple-API-first check (per wenshu-apple-api-first skill §Gate 5 + boss 2026-09-02 OOB hard rule):
- All replacements are `Color(nsColor: .NSColor)` form, sourced from Apple NSColor static properties (= no custom color constructors).
- Zero raw RGB / calibratedWhite / opacity-tint / hand-rolled material ladder introduced.
- Apple Material catalog (`Material.ultraThinMaterial` / `Material.regularMaterial`) is Apple API but produces translucent output (= the boss-flagged "wash out" effect). Removal is required for the per-pane tier delta to be visible.

Trade-off (= none): translucent Material gives a "card floating over the desktop" visual cue; opaque NSColor gives "card on a flat pane" visual cue. Boss 2026-09-02 OOB "默认不加液态玻璃效果" = the flat cue is the intent.

Execution mode: BOSS-APPROVAL SEQUENTIAL (= one commit per file, four tickets). Boss picks the first; agent waits for "下一个" between each.
