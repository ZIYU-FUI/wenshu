# macOS 26 Tahoe "Zero-Config Follow System" Iron Rules

**Status**: Project-level hard rule (老板 2026-09-02 OOB directive). Effective from v0.32 forward.
**Owner**: pocock single-agent.
**Review cadence**: Every new commit touching `Sources/WenshuApp/UI/`, `App.swift`, settings scene, or any custom color/font/material code must pass this audit BEFORE landing.

---

## The 11 Iron Rules (one each)

### Rule 1 — Colors: semantic only
Write `Color.primary` / `Color.secondary` / `Color.accentColor` / `Color(nsColor: .windowBackgroundColor)` etc. NEVER hardcode RGB / hex / `Color.red` / `Color(red:...)`.

### Rule 2 — Fonts: 11 text styles only
`.largeTitle` / `.title` / `.title2` / `.title3` / `.headline` / `.body` / `.callout` / `.subheadline` / `.footnote` / `.caption` / `.caption2`. NEVER `.system(size: 17)`.

### Rule 3 — Dark mode: implicit via semantic colors
NEVER `view.overrideUserInterfaceStyle = .dark`, NEVER `NSAppearance.customAppearanceNamed(.darkAqua)`, NEVER hardcode light/dark value. Optional `AppearanceMode` enum (.system default / .light / .dark) is allowed IF bridged via `.preferredColorScheme(...)`.

### Rule 4 — Glass: system presets only
`.glassEffect()` / `.glassEffect(.regular.tint(.accentColor))` / `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)`. Default `.regular`, default `Capsule()`, no manual shape, no manual non-accent color.

### Rule 5 — Accessibility: zero custom code
Reduce Transparency / Increase Contrast / Reduce Motion / Dynamic Type / Bold Text = automatic via Apple semantic APIs. NEVER `.animation(nil, value:)` to kill motion.

### Rule 6 — Layout / spacing: defaults only
NEVER `.padding(.all, 12)`, NEVER `Spacer().frame(height: 24)`. Use VStack/HStack defaults + `.padding()`.

### Rule 7 — Buttons / controls: system components only
`Button("Save")` + `.buttonStyle(.bordered / .borderedProminent / .glass / .glassProminent / .plain)`. Use `Toggle` / `Slider` / `TextField` / `Picker` — never custom-drawn.

### Rule 8 — Window / scene: standard scene types
`WindowGroup` + `Settings { }` + `MenuBarExtra`. NEVER self-written `NSApplicationDelegate` for window control.

### Rule 9 — Menu / shortcuts: standard command groups
`.commands { CommandGroup(replacing: .newItem) { Button(...).keyboardShortcut(...) } }`. NEVER hand-built menu.

### Rule 10 — Tab / navigation / search: three-piece kit
`NavigationSplitView` / `TabView` / `.searchable(text:placement:)`. NEVER hand-written sidebar.

### Rule 11 — State persistence: standard storage
`@AppStorage("...")` / `@SceneStorage("...")`. Window position/size auto-restored by AppKit.

---

## The "zero-config" mental model

> **Ask: "Does Apple have an official API for this visual/behavior?"**
> Yes → use it. No → **don't ship it**. Must-ship → use `NSAppearance` / `Color.accentColor` / `colorScheme` env so the user's system setting controls the app.

Implications:
- User changes accent color → app re-tints
- User toggles Dark Mode → app auto-switches
- User enables Reduce Transparency → glass dims
- User enables Increase Contrast → text boldens
- User enlarges system font size → text scales
- User enables Tinted mode → window picks wallpaper color
- User disables Liquid Glass → app falls back to plain background

**All free, IF you used semantic APIs above.**

---

## Anti-pattern warning (the brand-color trap)

If you want to "define a brand color matching your brand":
1. First choice: NO brand color, only `.accentColor` (user controls via System Settings)
2. Second choice: brand color only in logo / launch screen / one-time splash; UI internals all semantic
3. NEVER: brand color as background / button / text color

---

## Audit cross-reference

| Iron Rule | wenshu-apple-api-first section | wenshu-macos26-liquid-glass-pitfalls section |
|---|---|---|
| Rule 1 colors | Hard rule "你所有用的颜色, 都是 API 给的, 不要自定义" | Pitfall 23 Apple NSColor micro-differentiation |
| Rule 4 glass | (n/a — covered by Pitfall 22) | Pitfall 22 `.glassEffect` standalone modifier |
| Rule 7 controls | "能用系统控件就不要自绘" | (n/a) |
| Rule 10 nav | "用 NavigationSplitView 三件套" | (n/a) |

---

## Audit history

- v0.32 Tier-1 rank-3 (2026-09-02) — deleted `DesignColor` enum wrapper, `RegionHoverWash` ShapeStyle wrapper, replaced `.background(Color.white.opacity(0.25))` with bare `.thinMaterial` / Apple Material catalog.
- v0.32 Tier-1 rank-4 (2026-09-02) — deleted 5 dead OutlineViews; canonical `NewLibraryOutlineView` is 100% Apple HIG.

---

## Source

老板 2026-09-02 OOB raw doc, verbatim transcribed.
First line: macOS 26 Tahoe zero-config follow-system rule set.
Last line: Source — boss's 2026-09-02 OOB raw doc, verbatim transcribed.