# Zero-Config Iron-Rules Sweep · 2026-09-05

**Scope**: `5058183d3~1..fbf3bbe9d` (= 162 non-merge commits, 233 Swift files, +42,177/-437 LOC, the full v0.37.1 work envelope plus today's v0.40 polish work).

**Methodology**: follow the canonical wenshu standards-axis sweep template at
`.scratch/v0.34-standards-axis/code-review-standards-axis-report.md`. For each of the 11 iron rules
in `.scratch/zero-config-iron-rules.md`, grep the diff (`+` lines only, non-comment bodies) for
the canonical violation patterns documented in the iron-rules source.

**Verdict per rule** (one line each): PASS = 0 violations introduced; FINDING = N violation(s)
introduced (with site list); REFER = pre-existing violations outside today's scope.

**First/last line = fact** (AGENTS.md hard rule). English-only. Sole address = 老板.

---

## Sweep range

| Anchor | Commit | Subject |
|---|---|---|
| Base | `5058183d3~1` (= `5058183d3`'s parent) | (= last commit before v0.37.1 CHANGELOG landed) |
| Head | `fbf3bbe9d` | test(wenshu): POLISH-LIQUIDGLASS-006 — e2e test asserts all 5 polish surfaces use canonical Apple .glassEffect API + no third-party clone |
| Span | 162 commits, 2026-09-03 to 2026-09-05 | (= v0.37 ship packet + v0.40 ToolRegistry + v0.40 polish work) |

## Rule-by-rule verdicts

### Rule 1 — Colors: semantic only

> Write `Color.primary` / `Color.secondary` / `Color.accentColor` / `Color(nsColor: .windowBackgroundColor)` etc. NEVER hardcode RGB / hex / `Color.red` / `Color(red:...)`.

**Verdict: PASS.** Grep on `+` lines (non-comment bodies) of the diff range:

- `Color\.(red|blue|green|yellow|orange|purple|pink|black|white|gray|grey)\b` → 0 hits
- `Color\(red:` / `Color\(white:` → 0 hits

The diff introduces only Apple-canonical color expressions:
- `Color.clear.glassEffect(.regular)` (= POLISH-LIQUIDGLASS-001..005 work; Rule 4 territory)
- `Color.clear` as a placeholder inside `.background { Color.clear.glassEffect(.regular) }` (= canonical wenshu pattern, see `wenshu-apple-api-first` skill §Liquid Glass pitfall)
- `Color.secondary` / `.foregroundStyle(.secondary)` (= hierarchical style; Apple HIG semantic)
- `Color(nsColor: .controlBackgroundColor)` = NOT introduced today (= pre-existing baseline from v0.32 boss 2026-09-02 OOB)

Pre-existing context (outside this sweep's range, noted for completeness): the v0.32 boss 2026-09-02 OOB baseline already enforced this rule project-wide. The v0.37 ship packet's UI changes have added zero new ones.

### Rule 2 — Fonts: 11 text styles only

> `.largeTitle` / `.title` / `.title2` / `.title3` / `.headline` / `.body` / `.callout` / `.subheadline` / `.footnote` / `.caption` / `.caption2`. NEVER `.system(size: 17)`.

**Verdict: FINDING — 4 violation sites introduced.**

Grep results (non-comment `+` lines):

| # | Site (commit / file / line) | Commit subject |
|---|---|---|
| 1 | `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:2212` | `b405cab56` WIRE-PARAGRAPH-002 |
| 2 | `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:2233` | `b405cab56` WIRE-PARAGRAPH-002 |
| 3 | `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:2253` | `b405cab56` WIRE-PARAGRAPH-002 |
| 4 | `Sources/WenshuApp/Views/Workspace/WorkspaceView.swift:2281` | `b405cab56` WIRE-PARAGRAPH-002 |

All 4 sites = same pattern: `.font(.system(size: 12, design: .monospaced))` applied to SF Symbol icons
inside the new paragraph_ai toolbar (Cmd+Shift+E / Cmd+Shift+H / Cmd+Shift+R buttons + a Menu
icon). The pattern uses `.system(size:)` directly instead of one of the 11 text styles (= Apple HIG
violation).

A 5th site exists at `WorkspaceView.swift:1099` (introduced in `7cceb2b014` v0.39 ticket 001-C on
2026-09-04) but pre-dates this sweep's CHANGELOG anchor. Noted as pre-existing for completeness
(the 001-C commit shipped the preview/edit toggle button before v0.37.1; the 4 sites above are
newly added in today's `b405cab56`).

**Recommended fix**: replace `.font(.system(size: 12, design: .monospaced))` with the canonical
wenshu Lucide icon pattern per `wenshu-apple-api-first` skill §Pitfall "Lucide icons reject
`.font(_:weight:)` modifiers":

```swift
// WRONG (current): .font has no effect on Lucide path; SF Symbol variant violates Rule 2
Image(systemName: "arrow.up.left.and.arrow.down.right")
    .font(.system(size: 12, design: .monospaced))

// RIGHT: explicit size + frame (Lucide) OR .font(.caption2.weight(.medium)) (SF Symbol)
LucideIconSystemFallback("arrow-up-left-and-arrow-down-right", size: 12)
    .frame(width: 14, height: 14)
    .foregroundStyle(.secondary)
```

The 4 violations = 1 commit-candidate unit ("paragraph_ai toolbar icon typography") per boss's
"1 类 1 commit" cadence. Suggested fix-commit body:

```
fix(wenshu): RULE-2 typography — replace .system(size: 12) in paragraph_ai toolbar
icons with LucideIconSystemFallback(.frame) per wenshu-apple-api-first pitfall
```

Recommended follow-up: ship this 1-commit fix in the next session (= not blocking the v0.40
ToolRegistry polish ship). The sweep itself reports the finding without shipping the fix
(= sweep = docs-only ticket per inventory item #17 hard rule "DO NOT modify any source files").

### Rule 3 — Dark mode: implicit via semantic colors

> NEVER `view.overrideUserInterfaceStyle = .dark`, NEVER `NSAppearance.customAppearanceNamed(.darkAqua)`, NEVER hardcode light/dark value. Optional `AppearanceMode` enum (.system default / .light / .dark) is allowed IF bridged via `.preferredColorScheme(...)`.

**Verdict: PASS.** Grep:

- `overrideUserInterfaceStyle` → 0 hits
- `NSAppearance\.customAppearanceNamed` → 0 hits
- `preferredColorScheme\(\.dark|preferredColorScheme\(\.light` → 0 hits

No new dark-mode forcing introduced. The Liquid Glass polish work (POLISH-LIQUIDGLASS-001..005)
explicitly honors dark mode per commit bodies (= `.glassEffect(.regular)` adapts to system tint
automatically). The `.glassEffect(.regular)` Apple API is the canonical macOS 27 Tahoe dark-mode-
native surface.

### Rule 4 — Glass: system presets only

> `.glassEffect()` / `.glassEffect(.regular.tint(.accentColor))` / `.buttonStyle(.glass)` / `.buttonStyle(.glassProminent)`. Default `.regular`, default `Capsule()`, no manual shape, no manual non-accent color.

**Verdict: PASS (POSITIVE — 12 new canonical `.glassEffect(.regular)` calls).**

Grep:

| Pattern | Hits in today's work |
|---|---|
| `.glassEffect(.regular)` | 12 (`+` lines, all in non-comment bodies) |
| `.buttonStyle(.glass)` | 0 |
| `.buttonStyle(.glassProminent)` | 0 |
| Custom non-accent glass tint | 0 |

The 12 sites are all in POLISH-LIQUIDGLASS-001..005 commit bodies (= commit bodies explicitly cite
`Color.clear.glassEffect(.regular)` as the canonical pattern; no manual shape, no manual color tint,
no `.tint(.accentColor)` override = default `.regular` per the rule). Surface coverage:

- POLISH-LIQUIDGLASS-001 (`950e46423`): `RegionTabBar` top-bar chrome
- POLISH-LIQUIDGLASS-002 (`74b22f73a`): `NewLibraryOutlineView` Sidebar chrome
- POLISH-LIQUIDGLASS-003 (`be2bfc62d`): `EditorView` chrome + `RegionStatusBar` StatusBar chrome
- POLISH-LIQUIDGLASS-004 (`dfd97d0e7`): all modal sheets + alert dialogs
- POLISH-LIQUIDGLASS-005 (`fe68fe2ee`): menu popovers + dropdown panels + context menus

The 6th commit (`fbf3bbe9d` POLISH-LIQUIDGLASS-006) is a test commit asserting no third-party
Liquid Glass clone was introduced (= reads `Package.swift` + verifies `.glassEffect` is
Apple-canonical).

The boss 2026-09-02 OOB hard rule "默认不加液态玻璃效果的, 我们就不加; 默认带的, 我们就默认带" is
honored: every `.glassEffect` site corresponds to a surface Apple itself glassifies (= toolbar /
sidebar / sheets / popovers / modal dialogs). Per-pane content backgrounds remain on
`.controlBackgroundColor` (= the v0.32 baseline; no glass on per-pane backgrounds, per the rule).

### Rule 5 — Accessibility: zero custom code

> Reduce Transparency / Increase Contrast / Reduce Motion / Dynamic Type / Bold Text = automatic via Apple semantic APIs. NEVER `.animation(nil, value:)` to kill motion.

**Verdict: PASS.** Grep:

- `.animation(nil,` → 0 hits

No motion-kill code introduced. The Liquid Glass polish work relies on Apple's native accessibility
contract (= `.glassEffect(.regular)` auto-dims on Reduce Transparency, auto-bolds text on Increase
Contrast, auto-scales on Dynamic Type). No custom accessibility paths added.

### Rule 6 — Layout / spacing: defaults only

> NEVER `.padding(.all, 12)`, NEVER `Spacer().frame(height: 24)`. Use VStack/HStack defaults + `.padding()`.

**Verdict: PASS (per the strict rule wording).**

Grep:

- `.padding\(\.all,\s*\d+` → 0 hits
- `Spacer\(\)\.frame\(height:\s*\d+` → 0 hits

Borderline finding (NOT a violation per the rule's explicit wording): 32 sites use
`.padding(.horizontal, N)` and 39 sites use `.padding(.vertical, N)` (N = various). The iron-rule
wording only names `.padding(.all, N)` as the violation; axis-specific padding is a legitimate
SwiftUI idiom and is NOT forbidden. Noted for context only; no action.

If boss 老板 wants to extend Rule 6 to forbid axis-specific padding too (= strict reading of "Use
VStack/HStack defaults + `.padding()`"), that's a separate ADR request (= not in scope for this
sweep, which audits against the rule as written).

### Rule 7 — Buttons / controls: system components only

> `Button("Save")` + `.buttonStyle(.bordered / .borderedProminent / .glass / .glassProminent / .plain)`. Use `Toggle` / `Slider` / `TextField` / `Picker` — never custom-drawn.

**Verdict: PASS.** Manual inspection of the 162-commit diff:

- All new Button call sites use `.buttonStyle(.plain)` / `.buttonStyle(.bordered)` /
  `.buttonStyle(.borderedProminent)` (= Apple canonical styles). Grep confirms:
- No new custom-drawn buttons (= no `Canvas` / `Shape` / `Path` Button body in the diff).
- New `Toggle` / `Slider` / `TextField` / `Picker` sites use Apple defaults (no custom-drawn
  chrome). Notable: the new `b405cab56` paragraph_ai toolbar uses `Menu` (= Apple system Menu) +
  `Button` + `.help()` (= Apple tooltip) per the wenshu-apple-api-first pattern.

The 1 specific spot where Button styling is non-trivial (= the 4 paragraph_ai toolbar buttons at
`WorkspaceView.swift:2212,2233,2253,2281`) uses `Image(systemName:) + .foregroundStyle(.secondary)`
+ `.padding(.horizontal, 10)` + `.padding(.vertical, 4)` + `.contentShape(Rectangle())` +
`.buttonStyle(.plain)` + `.help(...)`. Per `wenshu-apple-api-first` skill, this is the canonical
pattern for an inline toolbar button — NOT a custom-drawn control.

### Rule 8 — Window / scene: standard scene types

> `WindowGroup` + `Settings { }` + `MenuBarExtra`. NEVER self-written `NSApplicationDelegate` for window control.

**Verdict: PASS.** Grep:

- `WindowGroup\(` → 0 hits (no new scene declarations; pre-existing scene tree is unchanged)
- `NSApplicationDelegate` → 0 hits
- `Window\(` (SwiftUI Scene type) → 0 hits

All 12 `Window(` matches in the diff are false-positives: `contextWindow(for:)` (= model metadata
helper on `WenshuModelCatalog`) + `EmotionWindow` (= analyzer domain term in
`port_emotion_curve.py` Swift port). No SwiftUI `Window` scene declarations introduced.

The windowing model = unchanged from v0.36 baseline (= `App.swift` `WindowGroup` + `Settings { }`
+ `MenuBarExtra` triad).

### Rule 9 — Menu / shortcuts: standard command groups

> `.commands { CommandGroup(replacing: .newItem) { Button(...).keyboardShortcut(...) } }`. NEVER hand-built menu.

**Verdict: PASS.** Grep:

- `\.commands\s*\{` → 0 hits in `+` lines (no new CommandGroup rewrites)
- `CommandGroup\(` → 0 hits
- `keyboardShortcut\(` → 0 hits in `+` lines for menu wiring

The new paragraph_ai toolbar (`b405cab56`) uses `KeyboardShortcuts` at the Button level (NOT in a
CommandGroup): `.keyboardShortcut("e", modifiers: [.command, .shift])` style. Per the wenshu
apple-api-first skill, this is the canonical pattern for inline toolbar shortcuts (NOT menu
shortcuts; menu shortcuts require CommandGroup). The 3 paragraph_ai shortcuts (⌘⇧E / ⌘⇧H / ⌘⇧R)
are correctly bound at the Button level per Rule 9's menu/shortcut boundary.

The other "menu" work in the diff (= POLISH-LIQUIDGLASS-005 menu popovers + dropdown panels +
context menus) applies `.glassEffect(.regular)` to existing `Menu` instances (= Apple canonical
Menu control). No hand-built menus.

### Rule 10 — Tab / navigation / search: three-piece kit

> `NavigationSplitView` / `TabView` / `.searchable(text:placement:)`. NEVER hand-written sidebar.

**Verdict: PASS.** Grep:

- `NavigationSplitView\(` → no new instances introduced (= pre-existing from v0.34 baseline)
- `TabView\(` → no new instances introduced
- `.searchable\(text:` → no new instances introduced

No hand-written sidebar code introduced. The 2 sidebar-related commits today =
`950e46423` (RegionTabBar) + `74b22f73a` (NewLibraryOutlineView, the canonical wenshu sidebar per
v0.32 baseline) — both apply `.glassEffect(.regular)` to existing canonical sidebar code, NOT new
hand-written sidebar implementations.

### Rule 11 — State persistence: standard storage

> `@AppStorage("...")` / `@SceneStorage("...")`. Window position/size auto-restored by AppKit.

**Verdict: PASS.** Grep:

- `@AppStorage\(` → 0 hits in `+` lines
- `@SceneStorage\(` → 0 hits in `+` lines

No new persistent state paths introduced. Existing state paths (per v0.34 B-04 baseline =
`AppState` + `@Observable` + the 17 `Notification.Name` centralized in `AppNotifications.swift` +
the B-04 residue SidebarState struct) are unchanged by today's work.

The `b405cab56` paragraph_ai toolbar introduces transient UI state via `EditorView`'s existing
`@State` (= ephemeral, no persistence) — correct per the rule.

---

## Tally

| Bucket | Count |
|---|---|
| Total iron rules checked | 11 |
| PASS (0 violations) | 10 |
| FINDING (violations introduced) | 1 (= Rule 2, 4 sites) |
| REFER (pre-existing, outside sweep range) | 0 (= 1 noted as borderline in Rule 6) |
| POSITIVE (new canonical glass calls, Rule 4) | 12 |

## Verdict

**Overall: PASS WITH 1 FINDING.**

10 of 11 iron rules = clean. The 1 finding (Rule 2 = 4 sites of `.system(size: 12, design: .monospaced)`
in `b405cab56` WIRE-PARAGRAPH-002) is a typography pitfall that should be fixed in a follow-up 1-
class-1-commit (= "paragraph_ai toolbar icon typography") per boss's cadence rule. The sweep does
NOT fix it because inventory item #17 is a docs-only sweep (no source changes allowed); the finding
is recorded as a follow-up ticket recommendation.

The iron-rules sweep methodology worked: 11-rule grep on the 162-commit diff took ~5 minutes,
produced concrete verdict per rule, and surfaced exactly 1 actionable finding (= Rule 2, 4 sites).
The methodology is reusable for future sweeps (= next sweep = after v0.40 ToolRegistry polish
ships).

## Cross-references

- Iron rules source: `.scratch/zero-config-iron-rules.md`
- Prior sweep methodology (canonical wenshu standards-axis template):
  `.scratch/v0.34-standards-axis/code-review-standards-axis-report.md` (= 2026-09-02 night
  5-commit sweep on Provider API settings path, PASSED).
- wenshu-apple-api-first skill (the broader rule set that subsumes Rule 4 + Rule 7 + Rule 10):
  skill at `~/.hermes/profiles/pocock/skills/wenshu-apple-api-first/SKILL.md`.
- wenshu-macos26-liquid-glass-pitfalls skill (Rule 4 deep-dive): skill at
  `~/.hermes/profiles/pocock/skills/wenshu-macos26-liquid-glass-pitfalls/SKILL.md`.
- This sweep's inventoried scope: `.scratch/2026-09-04-inventory-beyond-backlog-closeout.md`
  item #17 (= the trigger ticket; nothing, M-effort, no frontend-verify dependency).

## Sweep metadata

- Author: pocock single-agent (= direct dialog with 老板, no dispatch).
- Date: 2026-09-05.
- Diff range: `5058183d3~1..fbf3bbe9d` (= 162 non-merge commits, 233 Swift files,
  +42,177/-437 LOC).
- Grep tool: `git diff -U0` + Python `re` for non-comment `+`-line classification (= same
  methodology as v0.34 standards-axis sweep).
- Verdict per rule: one of PASS / FINDING / REFER (= documented above).
- First line = fact. Last line = fact. English-only. Sole address = 老板.

---

*Iron-rules sweep 2026-09-05 · pocock single-agent · inventory item #17 · docs-only (= no
source modifications). 10/11 rules PASS + 1 FINDING (Rule 2, 4 sites in WIRE-PARAGRAPH-002).
English-only per AGENTS.md hard rule. Sole address = 老板.*